{ last                            } = require('brazierjs/array')
{ flip, pipeline                  } = require('brazierjs/function')
{ flatMap, fold, map, maybe, None } = require('brazierjs/maybe')
{ lookup                          } = require('brazierjs/object')

IntervalTree = require('interval-tree2')

# type Timing       = { start: Number, end: Number, domElement: DOMElement }
# type GentleWord   = { case: String, end: Number, endOffset: Number, start: Number, startOffset: Number, word: String }
# type GentleResult = { words: Array[GentleWord], transcript: String }

class TimingData

  _intervals:  undefined # IntervalTree
  _idsToElems: undefined # Object[Number, DOMElement]

  # (Number) => TimingData
  constructor: (midpoint) ->
    @_intervals = new IntervalTree(midpoint)
    @_idToElem  = {}

  # (Number, Number, DOMElement) => TimingData
  add: (start, end, elem) ->
    elemID = @_intervals.add(start - 0.01, end + 0.01).id
    @_idToElem[elemID] = elem
    this

  # (Number) => Maybe[DOMElement]
  lookup: (time) ->
    intervals = @_intervals.pointSearch(time)
    pipeline(last, maybe, map((i) -> i.id), flatMap(flip(lookup)(@_idToElem)))(intervals)

# (() => Maybe[DOMElement], (DOMElement) => DOMElement, Maybe[DOMElement], () => Boolean) => () => Unit
highlightWord = (getCurrentWord, makeActive, highlightedElem, isPaused) -> ->

  nextElem = getCurrentWord()

  newHighlightedElem =
    if fold(-> false)((highlighted) -> fold(-> false)((elem) -> highlighted is elem)(nextElem))(highlightedElem)
      highlightedElem
    else
      map(makeActive)(nextElem)

  window.requestAnimationFrame(highlightWord(getCurrentWord, makeActive, newHighlightedElem, isPaused))

  return

# (DOMElement, DOMElement, GentleResult) => Unit
render = (audioElem, transcriptElem, { words = [], transcript }) ->

  makeActive = (elem) ->
    activeClassName = 'active'
    Array.from(document.querySelectorAll(".#{activeClassName}")).forEach((node) -> node.classList.remove(activeClassName))
    elem.classList.add(activeClassName)
    elem

  transcriptElem.innerHTML = ''

  timingData = new TimingData(last(words).end / 2)

  [filledTimingData, finalOffset] =
    words.reduce(
      ([acc, currentOffset], { 'case': wordCase, end, endOffset, start, startOffset, word }) ->

        if wordCase is 'not-found-in-transcript'
          transcriptElem.appendChild(document.createTextNode(" #{word}"))
          [acc, currentOffset]
        else

          # Add non-linked text
          if startOffset > currentOffset
            transcriptElem.appendChild(document.createTextNode(transcript.slice(currentOffset, startOffset)))

          wordElem = document.createElement('span')
          wordElem.appendChild(document.createTextNode(transcript.slice(startOffset, endOffset)))

          newAcc =
            if start?
              wordElem.className = 'success'
              wordElem.onclick =
                ->
                  makeActive(wordElem)
                  audioElem.currentTime = start
                  audioElem.play()
                  return
              acc.add(start, end, wordElem)
            else
              acc

          transcriptElem.appendChild(wordElem)

          [newAcc, endOffset]

    , [timingData, 0])

  transcriptElem.classList.remove('prealignment')
  transcriptElem.appendChild(document.createTextNode(transcript.slice(finalOffset, transcript.length)))

  audioElem.addEventListener('playing', ->
    window.requestAnimationFrame(highlightWord((-> filledTimingData.lookup(audioElem.currentTime)), makeActive, None, -> audioElem.paused))
  )

  return

# (DOMElement, DOMElement) => Unit
module.exports = (audioElem, transcriptElem) ->

  window.onkeydown = (e) ->
    switch e.keyCode
      when 32
        e.preventDefault()
        if audioElem.paused
          audioElem.play()
        else
          audioElem.pause()
    return

  makeFormData = (parameters) ->
    formData = new FormData
    for k, v of parameters
      formData.set(k, v)
    formData

  tURL = 'http://localhost:8765/transcriptions?async=false'

  fetch(new Request(audioElem.src)).then(
    (audioResponse) -> audioResponse.blob()
  ).then(
    (audio) -> fetch(tURL, { method: "POST", body: makeFormData({ audio, transcript: transcriptElem.innerText }) })
  ).then(
    (data) -> data.json()
  ).then(
    (json) -> render(audioElem, transcriptElem, json)
  )

  return
