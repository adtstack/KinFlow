const contractVersion = "2026-07-24";
const allowedOrigin = "http://127.0.0.1:3000";
const requestIdPattern = /^[A-Za-z0-9_-]{1,64}$/;

function responseHeaders(requestId: string): HeadersInit {
  return {
    "access-control-allow-headers": "authorization, apikey, content-type, x-request-id",
    "access-control-allow-methods": "GET, POST, OPTIONS",
    "access-control-allow-origin": allowedOrigin,
    "cache-control": "no-store",
    "content-type": "application/json; charset=utf-8",
    "x-request-id": requestId,
  };
}

function requestIdFor(request: Request): string {
  const candidate = request.headers.get("x-request-id") ?? "";
  return requestIdPattern.test(candidate) ? candidate : crypto.randomUUID();
}

Deno.serve((request: Request): Response => {
  const requestId = requestIdFor(request);

  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: responseHeaders(requestId),
    });
  }

  if (request.method !== "GET" && request.method !== "POST") {
    return Response.json(
      {status: "error", code: "METHOD_NOT_ALLOWED", requestId},
      {status: 405, headers: responseHeaders(requestId)},
    );
  }

  return Response.json(
    {
      status: "ok",
      service: "kinflow-edge",
      contractVersion,
      environment: "local",
      requestId,
    },
    {status: 200, headers: responseHeaders(requestId)},
  );
});
