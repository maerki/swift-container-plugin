//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftContainerPlugin open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftContainerPlugin project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftContainerPlugin project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ContainerRegistry

extension ImageSource {
    /// Copies a blob from another registry to this one.
    /// - Parameters:
    ///   - digest: The digest of the blob to copy.
    ///   - sourceRepository: The repository from which the blob should be copied.
    ///   - destClient: The client to which the blob should be copied.
    ///   - destRepository: The repository on this registry to which the blob should be copied.
    /// - Throws: If the copy cannot be completed.
    func copyBlob(
    digest: ImageReference.Digest,
    fromRepository sourceRepository: ImageReference.Repository,
    toClient destClient: ImageDestination,
    toRepository destRepository: ImageReference.Repository
) async throws {
    log("""
    📦 Starting blob copy:
      • Digest: \(digest)
      • Source repository: \(sourceRepository)
      • Destination repository: \(destRepository)
    """)

    log("🔍 Checking if layer \(digest) exists in destination repository")
    if try await destClient.blobExists(repository: destRepository, digest: digest) {
        log("✅ Layer \(digest): already exists in destination")
        return
    }

    log("📥 Layer \(digest): fetching from source")
    let blob: Data
    do {
        blob = try await getBlob(repository: sourceRepository, digest: digest)
        log("📦 Layer \(digest): successfully fetched (\(blob.count) bytes)")
    } catch {
        log("❌ Failed to fetch layer \(digest): \(error)")
        throw error
    }

    log("📤 Layer \(digest): pushing to destination")
    let uploaded: (digest: String, size: Int)
    do {
        uploaded = try await destClient.putBlob(repository: destRepository, data: blob)
        log("📬 Layer \(digest): successfully uploaded (digest: \(uploaded.digest), size: \(uploaded.size))")
    } catch {
        log("❌ Failed to upload layer \(digest): \(error)")
        throw error
    }

    if "\(digest)" != uploaded.digest {
        log("⚠️ Digest mismatch: expected \(digest), got \(uploaded.digest)")
        throw RegistryClientError.digestMismatch(expected: "\(digest)", registry: uploaded.digest)
    }

    log("✅ Layer \(digest): copy complete")
}
}
