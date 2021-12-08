/**
 * Webpack config to package the Pinput JS module together with a script to run it,
 * since web extensions can't handle modules.
 *
 * Development:
 *     webpack --config web/webpack.config.js --mode development --devtool cheap-module-source-map
 * Release:
 *     webpack --config web/webpack.config.js
 */

const path = require('path');

module.exports = {
    entry: path.resolve(__dirname, 'pinput-loader.js'),
    resolve: {
        modules: [__dirname],
    },
    output: {
        path: __dirname,
        filename: 'extension/pinput-extension.js',
    },
};
