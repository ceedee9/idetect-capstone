const path = require("path");
const { v4: uuidv4 } = require("uuid");
const supabase = require("../config/supabase");

const ID_IMAGES_BUCKET =
  process.env.SUPABASE_STORAGE_BUCKET_ID_IMAGES || "id-captures";
const DISPUTE_DOCS_BUCKET =
  process.env.SUPABASE_STORAGE_BUCKET_DISPUTE_DOCS || "dispute-docs";

function parseBase64Image(base64Data) {
  if (!base64Data || typeof base64Data !== "string") return null;

  const matches = base64Data.match(/^data:image\/(\w+);base64,(.+)$/);
  const ext = (matches ? matches[1] : "jpg").toLowerCase();
  const raw = matches ? matches[2] : base64Data;

  const mimeTypeMap = {
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    png: "image/png",
    webp: "image/webp",
    gif: "image/gif",
  };

  const resolvedExt = ext === "jpeg" ? "jpg" : ext;
  const contentType = mimeTypeMap[ext] || "image/jpeg";
  const buffer = Buffer.from(raw, "base64");

  if (!buffer.length) return null;
  return { buffer, ext: resolvedExt, contentType };
}

async function uploadIdCaptureBase64(base64Data) {
  const parsed = parseBase64Image(base64Data);
  if (!parsed) return null;

  const objectPath = `${Date.now()}-${uuidv4()}.${parsed.ext}`;
  const { error } = await supabase.storage
    .from(ID_IMAGES_BUCKET)
    .upload(objectPath, parsed.buffer, {
      contentType: parsed.contentType,
      upsert: false,
    });

  if (error) {
    console.warn(
      "⚠️ Failed to upload ID image to Supabase Storage:",
      error.message,
    );
    return null;
  }

  return { bucket: ID_IMAGES_BUCKET, objectPath };
}

async function uploadDisputeDocument({ buffer, originalname, mimetype }) {
  if (!buffer || !Buffer.isBuffer(buffer) || !buffer.length) {
    return null;
  }

  const ext = path.extname(originalname || "").toLowerCase() || ".bin";
  const objectPath = `dispute-doc-${Date.now()}-${Math.random().toString(36).slice(2)}${ext}`;

  const { error } = await supabase.storage
    .from(DISPUTE_DOCS_BUCKET)
    .upload(objectPath, buffer, {
      contentType: mimetype || "application/octet-stream",
      upsert: false,
    });

  if (error) {
    console.warn(
      "⚠️ Failed to upload dispute document to Supabase Storage:",
      error.message,
    );
    return null;
  }

  return { bucket: DISPUTE_DOCS_BUCKET, objectPath };
}

function buildAbsoluteApiUploadUrl(req, bucket, objectPath) {
  const host = `${req.protocol}://${req.get("host")}`;
  return `${host}/api/uploads/${bucket}/${objectPath}`;
}

function guessContentType(filePath) {
  const ext = path.extname(filePath || "").toLowerCase();
  const map = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".gif": "image/gif",
    ".pdf": "application/pdf",
  };
  return map[ext] || "application/octet-stream";
}

async function downloadStorageObject(bucket, objectPath) {
  const { data, error } = await supabase.storage
    .from(bucket)
    .download(objectPath);

  if (error || !data) {
    return null;
  }

  const arrayBuffer = await data.arrayBuffer();
  return {
    buffer: Buffer.from(arrayBuffer),
    contentType: data.type || guessContentType(objectPath),
  };
}

module.exports = {
  ID_IMAGES_BUCKET,
  DISPUTE_DOCS_BUCKET,
  uploadIdCaptureBase64,
  uploadDisputeDocument,
  buildAbsoluteApiUploadUrl,
  downloadStorageObject,
};
