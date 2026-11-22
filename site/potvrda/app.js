// Stranica na koju vodi dugme „Potvrdi adresu“ iz Tavli mejla.
// Supabase je adresu već potvrdio pre preusmeravanja ovde; stranica samo
// prosleđuje jednokratni `code` aplikaciji (tavli://auth-callback), koja ga
// menja za prijavu svojim PKCE verifikatorom. Kod nikad ne ide na mrežu odavde.
(function () {
  'use strict';

  var query = new URLSearchParams(window.location.search);
  var hash = new URLSearchParams(window.location.hash.replace(/^#/, ''));
  function param(name) {
    return query.get(name) || hash.get(name);
  }

  var code = param('code');
  var error = param('error') || param('error_code');
  var state = error ? 'greska' : code ? 'uspeh' : 'prazno';

  var link = 'tavli://auth-callback';
  if (state === 'uspeh') {
    link += '?code=' + encodeURIComponent(code);
  } else if (state === 'greska') {
    // Aplikacija za grešku prikazuje „Link je istekao“ sa „Pošalji ponovo“.
    link += '?error=' + encodeURIComponent(param('error') || 'access_denied');
    var errorCode = param('error_code');
    if (errorCode) link += '&error_code=' + encodeURIComponent(errorCode);
  }

  document.querySelectorAll('[data-stanje]').forEach(function (el) {
    el.hidden = el.getAttribute('data-stanje') !== state;
  });
  document.querySelectorAll('[data-otvori]').forEach(function (a) {
    a.setAttribute('href', link);
  });

  // Kod ne ostaje u adresnoj traci, istoriji ni u obeleživaču.
  if (code || error) {
    window.history.replaceState(null, '', window.location.pathname);
  }
})();
