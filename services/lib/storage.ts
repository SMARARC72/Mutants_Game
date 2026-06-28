// Storage uploader for generated art (TDD §5.6). Canonical path:
//   art/{player_id}/{instance_id}/{sigil_seed}.png
// Public-read bucket (`creature-art`), service-write. Behind an interface so the pipeline
// uploads to a fake in tests. The Supabase-backed impl uses the service-role client.

import type { SupabaseClient } from "@supabase/supabase-js";
import { ApiError } from "./errors.js";

export interface StorageUploader {
  /** Upload bytes and return a public URL. `upsert` keeps generate-once idempotent on retry. */
  upload(args: {
    path: string;
    bytes: Uint8Array;
    contentType: string;
  }): Promise<{ publicUrl: string }>;
}

export function artStoragePath(playerId: string, instanceId: string, sigilSeed: number): string {
  return `art/${playerId}/${instanceId}/${sigilSeed}.png`;
}

export function supabaseStorage(client: SupabaseClient, bucket: string): StorageUploader {
  return {
    async upload({ path, bytes, contentType }) {
      const { error } = await client.storage
        .from(bucket)
        .upload(path, bytes, { contentType, upsert: true });
      if (error) throw new ApiError("upstream_error", "Storage upload failed.");
      const { data } = client.storage.from(bucket).getPublicUrl(path);
      return { publicUrl: data.publicUrl };
    },
  };
}
