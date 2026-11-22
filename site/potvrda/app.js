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

  // Posle „Otvori Tavli“ prozor se sam zatvara kad se aplikacija otvori.
  // Stranica to ne može da zna direktno, pa gleda dva znaka:
  // - stranica je sakrivena (telefon: aplikacija je preko nje);
  // - prozor je izgubio fokus pa ga ponovo dobio (računar: aplikacija se
  //   otvorila, ili je korisnik odgovorio na pitanje pregledača „Otvori
  //   Tavli?“). Odmah na gubitak fokusa ne zatvaramo, jer bi to zatvorilo
  //   i to pitanje pre nego što korisnik odgovori.
  // Pregledač dozvoljava zatvaranje samo prozora otvorenog iz mejla (jedna
  // stavka u istoriji); inače ostaje napomena da prozor može da se zatvori.
  var opened = false;
  var leftPage = false;
  function tryClose() {
    if (!opened || !leftPage) return;
    window.setTimeout(function () {
      window.close();
    }, 300);
  }
  document.querySelectorAll('[data-otvori]').forEach(function (a) {
    a.addEventListener('click', function () {
      opened = true;
      leftPage = false;
      document.querySelectorAll('[data-posle-klika]').forEach(function (el) {
        el.hidden = el.getAttribute('data-posle-klika') !== state;
      });
    });
  });
  window.addEventListener('blur', function () {
    if (opened) leftPage = true;
  });
  window.addEventListener('focus', tryClose);
  document.addEventListener('visibilitychange', function () {
    if (!opened) return;
    if (document.visibilityState === 'hidden') {
      leftPage = true;
      tryClose();
    }
  });

  // Kod ne ostaje u adresnoj traci, istoriji ni u obeleživaču.
  if (code || error) {
    window.history.replaceState(null, '', window.location.pathname);
  }
})();
