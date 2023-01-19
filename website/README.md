This website is a work in progress.

---

# Start package for [Bulma](http://bulma.io)

Tiny npm package that includes the `npm` **dependencies** you need to **build your own website** with Bulma.

<a href="http://bulma.io"><img src="https://raw.githubusercontent.com/jgthms/bulma-start/master/bulma-start.png" alt="Bulma: a Flexbox CSS framework" style="max-width:100%;" width="600" height="315"></a>

## Install

```sh
npm install bulma-start
```
_or_

```sh
yarn add bulma-start
```

## What's included

The `npm` dependencies included in `package.json` are:

* <code>[bulma](https://github.com/jgthms/bulma)</code>
* <code>[node-sass](https://github.com/sass/node-sass)</code> to compile your own Sass file
* <code>[postcss-cli](https://github.com/postcss/postcss-cli)</code> and <code>[autoprefixer](https://github.com/postcss/autoprefixer)</code> to add support for older browsers
* <code>[babel-cli](https://babeljs.io/docs/usage/cli/)</code>, <code>[babel-preset-env](https://github.com/babel/babel-preset-env)</code> and <code>[babel-preset-es2015-ie](https://github.com/jmcriffey/babel-preset-es2015-ie)</code> for compiling ES6 JavaScript files

Apart from `package.json`, the following files are included:

* `.babelrc` configuration file for [Babel](https://babeljs.io/)
* `.gitignore` common [Git](https://git-scm.com/) ignored files
* `index.html` this HTML5 file
* `_sass/main.scss` a basic SCSS file that **imports Bulma** and explains how to **customize** your styles, and compiles to `css/main.css`
* `_javascript/main.js` an ES6 JavaScript that compiles to `lib/main.js`


## Get your feet wet

This package is meant to provide a **good starting point** for working with Bulma.

When installing this package with the commands above, it landed in `$HOME/node_packages/bulma-start`.
In order to use it as a **template** for your **project**, you might consider copying it to a better suited location:

```sh
cd $HOME/projects
cp -a $HOME/node_modules/bulma-start my-bulma-project
```

Alternatively, you could do something similar with a GitHub clone as well.

```sh
cd $HOME/projects
git clone https://github.com/jgthms/bulma-start
mv bulma-start my-bulma-project
rm -rf my-bulma-project/.git     # cut its roots
```

Now, that you prepared the groundwork for your project, set up Bulma and run the watchers:

```sh
cd my-bulma-project
npm install
npm start
```

As long as `npm start` is running, it will **watch** your changes. You can edit `_sass/main.scss` and `_javascript/main.js` at will. Changes are **immediately** compiled to their destinations, where `index.html` will pick them up upon reload in your browser.

Some controlling output is written to the `npm start` console in that process:

```sh
_javascript/main.js -> lib/main.js

=> changed: $HOME/projects/start-with-bulma/_sass/main.scss
Rendering Complete, saving .css file...
Wrote CSS to $HOME/projects/start-with-bulma/css/main.css
```

Use `npm run` to show all available commands:

```sh
Lifecycle scripts included in bulma-start:
  start
    npm-run-all --parallel css-watch js-watch

available via `npm run-script`:
  css-build
    node-sass _sass/main.scss css/main.css
  css-deploy
    npm run css-build && npm run css-postcss
  css-postcss
    postcss --use autoprefixer --output css/main.css css/main.css
  css-watch
    npm run css-build -- --watch
  deploy
    npm run css-deploy && npm run js-build
  js-build
    babel _javascript --out-dir lib
  js-watch
    npm run js-build -- --watch
```

If you want to learn more, follow these links: [Bulma homepage](http://bulma.io) and [Documentation](http://bulma.io/documentation/overview/start/).


## Copyright and license

Code copyright 2017 Jeremy Thomas. Code released under [the MIT license](https://github.com/jgthms/bulma-start/blob/master/LICENSE).
