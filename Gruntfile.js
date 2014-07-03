module.exports = function(grunt) {

    'use strict';

    // Project configuration.
    grunt.initConfig({

        pkg: grunt.file.readJSON('package.json'),

        watch: {
            flash: {
                files: [
                    'flash/{,*/}*.as'
                ],
                tasks: ['mxmlc:server']
            },
            gruntfile: {
                files: ['Gruntfile.js'],
                tasks: ['jshint']
            },
            html: {
                files: ['demo/*.html']
            },
            js: {
                files: [
                    'javascript/{,*/}*.js',
                    'javascript/lib/{,*/}*.js',
                    '!javascript/vendor/*'

                ],
                tasks: ['jshint'],
                options: {
                    livereload: true
                }
            },
            livereload: {
                options: {
                    livereload: 35729
                },
                files: [
                    'javascript/{,*/}*.js',
                    'javascript/lib/{,*/}*.js',
                    'flash/{,*/}*.as',
                    'demo/*.html',
                    'scss/{,*/}*.scss',
                    '!javascript/vendor/*'
                ]
            }
        },

        // The actual grunt server settings
        connect: {
            options: {
                port: 9000,
                open: true,
                livereload: 35729,
                // Change this to '0.0.0.0' to access the server from outside
                hostname: 'localhost'
            },
            livereload: {
                options: {
                    middleware: function(connect) {
                        return [
                            connect.static('.tmp/'),
                            connect().use('/javascript', connect.static('javascript/')),
                            connect().use('/bower_components', connect.static('bower_components/')),
                            connect.static('demo/')
                        ];
                    }
                }
            },
            build: {
                options: {
                    base: 'build',
                    livereload: false
                }
            }
        },

        clean: {
            build: {
                files: [{
                    dot: true,
                    src: [
                        '.tmp',
                        'build'
                    ]
                }]
            },
            server: '.tmp',
            tmp: '.tmp'
        },

        processhtml: {
            options: {
            // Task-specific options go here.
            },
            build: {
                files: {
                    'build/index.html' : ['demo/index.html']
                }
            }
        },

        jshint: {
            options: {
                jshintrc: '.jshintrc',
                reporter: require('jshint-stylish')
            },
            all: [
                'Gruntfile.js',
                'javascript/{,*/}*.js',
                'javascript/lib/{,*/}*.js',
                '!javascript/vendors/*'
            ]
        },

        copy: {
            server: {
                files: [
                    {
                        src: 'bower_components/swfobject/swfobject/expressInstall.swf',
                        dest: '.tmp/swf/expressInstall.swf'
                    }
                ]
            },
            build: {
                files: [
                    {
                        src: 'bower_components/jquery/dist/jquery.min.js',
                        dest: 'build/vendors/jquery.min.js'
                    },
                    {
                        src: 'bower_components/swfobject/swfobject/swfobject.js',
                        dest: 'build/vendors/swfobject.min.js'
                    },
                    {
                        src: 'bower_components/swfobject/swfobject/expressInstall.swf',
                        dest: 'build/swf/expressInstall.swf'
                    }
                ]
            }
        },

        modernizr: {

            build: {
                devFile : 'bower_components/modernizr/modernizr.js',
                outputFile : '.tmp/vendors/modernizr.js',
                parseFiles : true,
                extra : {
                    shiv : false,
                    load: false,
                    printshiv : false,
                    cssclasses : false
                },
                extensibility : {
                    addtest : true,
                    prefixed : true,
                    teststyles : false,
                    testprops : false,
                    testallprops : false,
                    hasevents : false,
                    prefixes : false,
                    domprefixes : false
                },
                files : {
                    src: [
                        'javascript/{,*/}*.js',
                        '!javascript/vendors/*',
                        '!bower_components/*'
                    ]
                }
            }

        },

        mxmlc: {
            options: {
                //rawConfig: '-source-path=/www/_lib/as3corelib/src/ -target-player=9.0 -external-library-path=node_modules/flex-sdk/lib/flex_sdk/frameworks/libs/player/9.0/playerglobal.swc -library-path=node_modules/flex-sdk/lib/flex_sdk/frameworks/libs/player/9.0'
                rawConfig: '-source-path=/www/_lib/as3corelib/src/ -target-player=11.0'
            },
            server: {
                files: {
                    '.tmp/swf/camcorder.swf': ['flash/Camcorder.as']
                }
            },
            build: {
                files: {
                    'build/swf/camcorder.swf': ['flash/Camcorder.as']
                }
            }
        },

        requirejs: {
            options: {
                baseUrl: 'javascript',
                mainConfigFile: 'javascript/main.js',
                name: '../bower_components/almond/almond',
                path: {
                    'modernizr' : '.tmp/vendors/modernizr',
                    'modernizr-getusermedia' : 'empty:'
                },
                include: ['main'],
                wrap: {
                    startFile: 'javascript/build/start.frag',
                    endFile: 'javascript/build/end.frag'
                },
                preserveLicenseComments: true
            },
            build: {
                options: {
                    optimize: 'none',
                    out: './build/camcorder.js'
                }
            },
            buildMin: {
                options: {
                    out: './build/camcorder.min.js'
                }
            }
        },

        concurrent: {
            server: [
                'mxmlc:server'
            ],
            build: [
                'mxmlc:build',
                'requirejs:build',
                'requirejs:buildMin'
            ]
        }
    });

    // Load the plugin that provides the 'uglify' task.
    require('load-grunt-tasks')(grunt);

    grunt.registerTask('serve', function (target) {
        if (target === 'build') {
            return grunt.task.run(['build', 'connect:build:keepalive']);
        }

        grunt.task.run([
            'clean:server',
            'copy:server',
            'concurrent:server',
            'connect:livereload',
            'watch'
        ]);
    });

    // Default task(s).
    grunt.registerTask('build', [
        'clean:build',
        'modernizr:build',
        'concurrent:build',
        'copy:build',
        'processhtml:build',
        'clean:tmp'
    ]);

    // Default task(s).
    grunt.registerTask('default', [
        'jshint',
        'build'
    ]);

};
