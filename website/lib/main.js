'use strict';

const install_guides_ids = ["install-linux", "install-macos", "install-windows"]

function hide_all_guides() {
  for (const id of install_guides_ids) {
    document.getElementById(id).style.display = 'none';
  }
}

function change_install_guide(guide) {
  const element = guide || document.location.hash.replace('#', '');

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

  document.querySelectorAll("#installPlatforms ul li a").forEach(el => {
    el.addEventListener('click', function (el) {
      const guide = new URL(el.target.href).hash.replace("#", "");
      change_install_guide(guide);
    });
  })

});

