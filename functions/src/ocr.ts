import * as vision from "@google-cloud/vision";

const client = new vision.ImageAnnotatorClient();

export async function extractMonto(imageUri: string): Promise<{
  monto: number | null;
  raw: string;
  confianza: number;
}> {
  const [result] = await client.textDetection(imageUri);
  const raw = result.fullTextAnnotation?.text ?? "";

  const patterns = [
    /\$\s*([\d]{1,3}(?:\.\d{3})*(?:,\d{2})?)/g,
    /\$\s*([\d]+(?:,\d{2})?)/g,
    /([\d]{1,3}(?:\.\d{3})+(?:,\d{2})?)/g,
    /([\d]+[,\.]\d{2})/g,
  ];

  const amounts: number[] = [];
  for (const pattern of patterns) {
    let match;
    while ((match = pattern.exec(raw)) !== null) {
      const raw_num = match[1]
        .replace(/\./g, "")
        .replace(",", ".");
      const val = parseFloat(raw_num);
      if (!isNaN(val) && val > 0) amounts.push(val);
    }
    pattern.lastIndex = 0;
  }

  if (amounts.length === 0) return { monto: null, raw, confianza: 0 };

  // Pick the largest amount (most likely the transfer total)
  const monto = Math.max(...amounts);
  const confianza = result.fullTextAnnotation ? 0.85 : 0.3;

  return { monto, raw, confianza };
}
