// The browser keeps the invite code in its URL fragment. The server only
// redirects to the app. Preview and confirmation still require sign-in.
Deno.serve((request: Request) => {
  if (request.method !== "GET") {
    return new Response(null, { status: 405, headers: { Allow: "GET" } });
  }

  return new Response(null, {
    status: 302,
    headers: {
      Location: "tavli://household/join",
      "Cache-Control": "no-store",
      "Referrer-Policy": "no-referrer",
    },
  });
});
