const path = require('path')
const fs = require('fs')
const WebpackAssetsManifest = require('webpack-assets-manifest')
const yaml = require('js-yaml')
const omit = require('lodash/omit')
const camelcase = require('camelcase')

// Load webpacker.yml file using a YAML reader
const webpackerConfig = yaml.safeLoad(
  fs.readFileSync(
    path.resolve(__dirname, 'config/webpacker.yml'),
    'utf8'
  )
)

// Compute the directory where the entry files are located.
//  In our case, this will be 'app/frontend/src' + '',
//  i.e. just 'app/frontend/src'
//  Note: if we had wanted to place our entry files in a subdirectory, as Webpacker encourages,
//  we could have also specified a source_entry_path in the webpacker config file
const entriesDirectory = path.join(
  __dirname,
  `${webpackerConfig.production.source_path}/${webpackerConfig.production.source_entry_path}`
)

// Read the public_output_path where the packed files will be served out of
//  In our case, this will be a directory called "packs".
//  Note: If we wanted to specify a different directory for our Rails test environment,
//  we would need to do some conditional logic in computing this public path
const publicPath = webpackerConfig.production.public_output_path

// Compute the directory where the packed files will be output
//  In our case, this will be 'public/packs'
const outputDir =
  `${webpackerConfig.production.public_root_path}/${publicPath}`

// Generate a hash of "page" objects by reading all the JS files
//  within the entries directory and mapping the filename without
//  the extension to the path to the entry file
const pages = Object.assign(
  {},
  ...fs
    .readdirSync(entriesDirectory)
    .filter(file => file.endsWith('.js'))
    .map(entry => {
      return {
        [entry.replace('.js', '')]: `${entriesDirectory}/${entry}`
      }
  })
)

// Read the dev_server configuration from the webpacker config file
const devServerConfig = webpackerConfig.development.dev_server
// Convert the settings for webpack dev server to the format that Webpack expects them in
const devServer = Object.assign(
  {},
  ...Object.entries(omit(devServerConfig, ['hmr', 'pretty']))
    .map(([field, value]) => { 
      return {
        [camelcase(field)]: value 
      } 
    }),
  { hot: true }
)

module.exports = {
  publicPath,
  pages,
  outputDir,
  devServer,
  configureWebpack: {
    plugins: [
      new WebpackAssetsManifest({
        integrity: false,
        entrypoints: true,
        writeToDisk: true,
        publicPath: `/${publicPath}/`
      })
    ]
  },
  chainWebpack: config => {
    // Modify the options for the CopyWebpackPlugin.
    //  This tells Webpack which "public" directory to copy files from
    //  (production build only). This would default to the "public" directory.
    //  However, this is also where Webpack will be outputting built files,
    //  and would result in a infinite loop of copying files from one one directory
    //  into a nested directory. Instead, we use the "public" directory of our
    //  VueCLI application, which is 'app/frontend/public'
    config.plugin('copy').tap(([options]) => {
      options[0].from = 'app/frontend/public'
      return [options]
    })
  }
}