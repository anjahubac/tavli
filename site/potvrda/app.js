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

  var phone =
    /Android|iPhone|iPad|iPod/i.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

  if (phone) {
    // Na telefonu, posle dodira, pokušaj da zatvoriš stranicu kad se sakrije.
    var tapped = false;
    document.querySelectorAll('[data-otvori]').forEach(function (a) {
      a.addEventListener('click', function () {
        tapped = true;
        document.querySelectorAll('[data-posle-klika]').forEach(function (el) {
          el.hidden = el.getAttribute('data-posle-klika') !== state;
        });
      });
    });
    document.addEventListener('visibilitychange', function () {
      if (tapped && document.visibilityState === 'hidden') {
        window.setTimeout(function () {
          window.close();
        }, 300);
      }
    });
  } else if (state === 'uspeh') {
    // Pregledač može da blokira otvaranje ili da traži potvrdu. Stranica
    // ostaje otvorena da bi korisnik mogao da klikne „Otvori Tavli“.
    window.location.href = link;
  }
})();
