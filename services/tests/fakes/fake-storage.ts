// Fake StorageUploader: records uploads and returns a deterministic public URL.

import type { StorageUploader } from "../../lib/storage.js";

export interface FakeStorage extends StorageUploader {
  readonly uploads: Array<{ path: string; size: number; contentType: string }>;
  uploadCalls: number;
}

export function makeFakeStorage(publicBase = "https://cdn.example.test"): FakeStorage {
  const fake: FakeStorage = {
    uploads: [],
    uploadCalls: 0,
    async upload({ path, bytes, contentType }) {
      fake.uploadCalls += 1;
      fake.uploads.push({ path, size: bytes.byteLength, contentType });
      return { publicUrl: `${publicBase}/${path}` };
    },
  };
  return fake;
}
