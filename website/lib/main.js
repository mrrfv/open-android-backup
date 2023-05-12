'use strict';

var install_guides_ids = ["install-linux", "install-macos", "install-windows"];

function hide_all_guides() {
  var _iteratorNormalCompletion = true;
  var _didIteratorError = false;
  var _iteratorError = undefined;

  try {
    for (var _iterator = install_guides_ids[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true) {
      var id = _step.value;

      document.getElementById(id).style.display = 'none';
    }
  } catch (err) {
    _didIteratorError = true;
    _iteratorError = err;
  } finally {
    try {
      if (!_iteratorNormalCompletion && _iterator.return) {
        _iterator.return();
      }
    } finally {
      if (_didIteratorError) {
        throw _iteratorError;
      }
    }
  }
}

function change_install_guide(guide) {
  var element = guide || document.location.hash.replace('#', '');

  if (install_guides_ids.includes(element)) {
    hide_all_guides();
    document.getElementById(element).style.display = 'block';
  }
}

document.addEventListener('hashchange', change_install_guide);
document.addEventListener('DOMContentLoaded', function () {
  hide_all_guides();
  // if a guide hash is already present in the url, this will show the respective guide
  change_install_guide();

  document.querySelectorAll("#installPlatforms ul li a").forEach(function (el) {
    el.addEventListener('click', function (el) {
      var guide = new URL(el.target.href).hash.replace("#", "");
      change_install_guide(guide);
    });
  });
});