module.exports = (grunt) ->

  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    coffeelint: {
      app: ['src/main/coffee/**/*.coffee'],
      options: {
        configFile: 'coffeelint.json'
      }
    },
    coffee: {
      compile: {
        files: [
          {
            expand: true,
            cwd: 'src/main/coffee',
            src: ['**/*.coffee'],
            dest: 'target/js',
            ext: '.js'
          }
        ]
      }
    },
    browserify: {
      main: {
        src: ['target/js/alignment.js'],
        dest: 'target/main.js',
        options: {
          alias: []
        }
      }
    }
  })

  grunt.loadNpmTasks('grunt-browserify');
  grunt.loadNpmTasks('grunt-coffeelint');
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-copy')

  grunt.task.registerTask('fix_require', 'Adds "require" prefix', ->
    filepath    = './target/main.js'
    strContents = grunt.file.read(filepath)
    grunt.file.write(filepath, "window.require=#{strContents}")
    return
  )

  grunt.registerTask('default', ['coffeelint', 'coffee', 'browserify', 'fix_require'])
