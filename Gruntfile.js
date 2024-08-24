module.exports = function (grunt) {
    grunt.file.defaultEncoding = "utf8";
    grunt.file.preserveBOM = false;

    grunt.loadNpmTasks('grunt-exec');

    grunt.initConfig({
        exec: {
            fixCryptoApiImports: {
                command: function () {
                    switch (process.platform) {
                        case "darwin":
                            return `find ./node_modules/crypto-api/src/ \\( -type d -name .git -prune \\) -o -type f -print0 | xargs -0 sed -i '' -e '/\\.mjs/!s/\\(from "\\.[^"]*\\)";/\\1.mjs";/g'`;
                        default:
                            return `find ./node_modules/crypto-api/src/ \\( -type d -name .git -prune \\) -o -type f -print0 | xargs -0 sed -i -e '/\\.mjs/!s/\\(from "\\.[^"]*\\)";/\\1.mjs";/g'`;
                    }
                },
                stdout: false
            },
            fixSnackbarMarkup: {
                command: function () {
                    switch (process.platform) {
                        case "darwin":
                            return `sed -i '' 's/<div id=snackbar-container\\/>/<div id=snackbar-container>/g' ./node_modules/snackbarjs/src/snackbar.js`;
                        default:
                            return `sed -i 's/<div id=snackbar-container\\/>/<div id=snackbar-container>/g' ./node_modules/snackbarjs/src/snackbar.js`;
                    }
                },
                stdout: false
            },
            fixJimpModule: {
                command: function () {
                    switch (process.platform) {
                        case "darwin":
                            // Space added before comma to prevent multiple modifications
                            return `sed -i '' 's/"es\\/index.js",/"es\\/index.js" ,\\n  "type": "module",/' ./node_modules/jimp/package.json`;
                        default:
                            return `sed -i 's/"es\\/index.js",/"es\\/index.js" ,\\n  "type": "module",/' ./node_modules/jimp/package.json`;
                    }
                },
                stdout: false
            }
        },
    });
};
