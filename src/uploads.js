import fs from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";
import { runtimeDir } from "./config.js";

const MAX_ATTACHMENTS = 4;
const MAX_ATTACHMENT_BYTES = 8 * 1024 * 1024;
const ALLOWED_IMAGE_TYPES = new Map([
  ["image/jpeg", "jpg"],
  ["image/pjpeg", "jpg"],
  ["image/png", "png"],
  ["image/webp", "webp"],
  ["image/gif", "gif"],
  ["image/heic", "heic"],
  ["image/heif", "heif"],
  ["image/heic-sequence", "heic"],
  ["image/heif-sequence", "heif"]
]);
const MIME_BY_EXTENSION = new Map([
  ["jpg", "image/jpeg"],
  ["jpeg", "image/jpeg"],
  ["png", "image/png"],
  ["webp", "image/webp"],
  ["gif", "image/gif"],
  ["heic", "image/heic"],
  ["heif", "image/heif"]
]);

export async function saveImageAttachments({ sessionId, attachments = [] }) {
  if (!Array.isArray(attachments) || attachments.length === 0) {
    return [];
  }
  if (attachments.length > MAX_ATTACHMENTS) {
    throw new Error("too_many_attachments");
  }

  const uploadDir = path.join(runtimeDir(), "uploads", safePathSegment(sessionId));
  await fs.mkdir(uploadDir, { recursive: true, mode: 0o700 });

  const saved = [];
  for (const attachment of attachments) {
    const parsed = parseImageDataUrl(String(attachment.dataUrl || ""));
    const mimeType = supportedMimeType({
      dataUrlMimeType: parsed.mimeType,
      attachmentMimeType: attachment.type,
      name: attachment.name
    });
    if (!mimeType) {
      throw new Error("unsupported_attachment_type");
    }
    if (parsed.buffer.length > MAX_ATTACHMENT_BYTES) {
      throw new Error("attachment_too_large");
    }

    const extension = ALLOWED_IMAGE_TYPES.get(mimeType);
    const fileName = `${Date.now()}-${crypto.randomUUID()}.${extension}`;
    const filePath = path.join(uploadDir, fileName);
    await fs.writeFile(filePath, parsed.buffer, { mode: 0o600 });
    saved.push({
      type: "localImage",
      path: filePath,
      name: safeDisplayName(attachment.name || fileName),
      mimeType,
      size: parsed.buffer.length
    });
  }

  return saved;
}

function parseImageDataUrl(value) {
  const match = value.match(/^data:([^;,]+);base64,([A-Za-z0-9+/=\s]+)$/);
  if (!match) {
    throw new Error("invalid_attachment_data");
  }
  return {
    mimeType: match[1].toLowerCase(),
    buffer: Buffer.from(match[2].replace(/\s/g, ""), "base64")
  };
}

function supportedMimeType({ dataUrlMimeType, attachmentMimeType, name }) {
  const candidates = [
    normalizeMimeType(dataUrlMimeType),
    normalizeMimeType(attachmentMimeType),
    mimeTypeFromName(name)
  ];
  return candidates.find((mimeType) => ALLOWED_IMAGE_TYPES.has(mimeType)) || "";
}

function normalizeMimeType(value) {
  const mimeType = String(value || "").toLowerCase();
  if (mimeType === "image/jpg") return "image/jpeg";
  return mimeType;
}

function mimeTypeFromName(name) {
  const extension = String(name || "").toLowerCase().match(/\.([a-z0-9]+)$/)?.[1] || "";
  return MIME_BY_EXTENSION.get(extension) || "";
}

function safePathSegment(value) {
  return String(value || "session").replace(/[^a-zA-Z0-9_.-]/g, "_").slice(0, 120);
}

function safeDisplayName(value) {
  return path.basename(String(value || "image")).slice(0, 160);
}
