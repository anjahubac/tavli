// Strogo dekodiranje standardnog base64 sa dopunom (`=`), bez
// `Uint8Array.fromBase64`: Supabase edge runtime (kompatibilan sa Deno 2.1)
// tu metodu nema, pa je svaki zahtev sa slikom ranije bio odbijen.
const pattern =
  /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/;

export function decodeBase64(text: string): Uint8Array {
  if (!pattern.test(text)) throw new SyntaxError("invalid_base64");
  const binary = atob(text);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}
