window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'PRODUCTIVITY',
  nav: 'Tools locker',
  kicker: 'notes, photos, videos, files',
  title: 'Tools — the media locker',
  summary: `
    Four small apps behind one tab: Notes, Photos, Videos, Files. Together they are the
    evidence layer — the before-and-after shots, the certificate PDF, the scribbled measurement.
    Anything in the locker can be attached to a job, a quote or an invoice by
    <em>reference</em>, so a file is uploaded once and cited many times. Every upload is a
    two-phase write across Cloud Storage and the Realtime Database, with rollback if the second
    phase fails.`,
  blocks: [
    {
      title: 'The four tools',
      html: `
<table>
  <tr><th>Tool</th><th>RTDB path</th><th>Storage?</th><th>Extras</th></tr>
  <tr><td>Notes</td><td><code>userTools/{uid}/notes</code></td><td>No — text only</td><td>Title + body</td></tr>
  <tr><td>Photos</td><td><code>userTools/{uid}/photos</code></td><td><code>users/{uid}/tools/photos/{id}/</code></td><td>Auto-numbered <code>IMG000001</code>, compressed on the way in, full-screen viewer with swipe</td></tr>
  <tr><td>Videos</td><td><code>userTools/{uid}/videos</code></td><td><code>users/{uid}/tools/videos/{id}/</code></td><td>First-frame thumbnail via <code>video_thumbnail</code>, playback via <code>video_player</code></td></tr>
  <tr><td>Files</td><td><code>userTools/{uid}/files</code></td><td><code>users/{uid}/tools/files/{id}/</code></td><td>PDFs and documents, picked with <code>file_picker</code></td></tr>
</table>`,
    },
    {
      title: 'Pipeline — uploading a photo',
      html: `
<p>
  The order here is not accidental. The RTDB key is generated <em>first</em>
  (<code>push()</code> without a write) so it can be used as the Storage folder name — that is
  what keeps the two stores in step. If the metadata write then fails, the already-uploaded
  blob is deleted, because an orphaned object in Storage is invisible to the app and can never
  be cleaned up from the UI.
</p>`,
      caption: 'Photo upload — key first, blob second, metadata third, rollback on failure',
      mermaid: `sequenceDiagram
  autonumber
  participant U as User
  participant PU as PhotoUploadScreen
  participant SEQ as PhotoNumberSequence
  participant IP as image_picker
  participant CMP as flutter_image_compress
  participant R as PhotosRepository
  participant DB as RTDB userTools/{uid}/photos
  participant ST as Cloud Storage
  participant B as PhotosBloc

  U->>PU: camera or gallery
  PU->>IP: pick / capture
  IP-->>PU: File
  PU->>CMP: compress
  CMP-->>PU: smaller File
  PU->>SEQ: peek() → suggested title IMG000123
  U->>PU: confirm title + description, Upload

  PU->>R: upload(file, title, description, onProgress)
  R->>DB: ref.push() — generate the key ONLY
  DB-->>R: id
  R->>ST: putFile(users/{uid}/tools/photos/{id}/{name})
  ST-->>PU: snapshotEvents → progress bar
  ST-->>R: complete
  R->>ST: getDownloadURL()
  ST-->>R: url
  R->>DB: ref.set(ToolPhoto record)
  alt metadata write fails
    R->>ST: delete the blob — no orphans
    R-->>PU: null → error toast
  else ok
    DB-->>B: watchAll() tick
    B-->>PU: grid shows the new photo
    PU->>SEQ: consume() — advance the counter
  end`,
    },
    {
      title: 'Pipeline — deleting, in the reverse order',
      html: `
<p>
  Delete mirrors the upload: the blob goes first, the record second. If it were the other way
  round and the Storage delete failed, the app would have lost the <code>storagePath</code>
  needed to ever try again.
</p>`,
      caption: 'Delete ordering',
      mermaid: `graph LR
  A["Delete tapped"] --> B["read photo.storagePath<br/>from the record"]
  B --> C["Storage.ref(path).delete()"]
  C --> D["RTDB userTools/{uid}/photos/{id}.remove()"]
  D --> E["stream tick → grid refreshes"]
  C -.->|"already gone / permission error"| F["swallowed — proceed to remove<br/>the record anyway"]
  F --> D`,
    },
    {
      title: 'Pipeline — attaching to a document',
      html: `
<p>
  The picker screens do not upload anything. They read the tool BLoC that is already streaming,
  let the user multi-select, and hand back model references which are copied onto the record's
  <code>attached*</code> array. This is why the same site photo can appear on the job, on the
  quote and on the final invoice without tripling storage cost.
</p>`,
      caption: 'One upload, many citations',
      mermaid: `graph TB
  A["Photo uploaded once"] --> B["Storage blob<br/>users/{uid}/tools/photos/{id}/"]
  A --> C["RTDB record with url + storagePath"]
  C --> D["PhotosBloc live list"]
  D --> E["PhotosPickerScreen"]
  E --> F["Job.attachedPhotos"]
  E --> G["Quote.attachedPhotos"]
  E --> H["Invoice.attachedPhotos"]
  G --> I["Public viewer asset proxy<br/>GET /q/:token/v/photo/:id"]
  H --> J["GET /i/:token/d/file/:id — download"]`,
    },
    {
      title: 'Numbering that survives reinstalls differently',
      html: `
<p>
  <code>PhotoNumberSequence</code> and <code>VideoNumberSequence</code> keep the next number in
  <code>shared_preferences</code> (<code>tools.photos.nextNumber</code>), formatted as
  <code>IMG000001</code> / the video equivalent. They expose <code>peek()</code> for the
  suggested title and <code>consume()</code> only after a successful upload — so a cancelled
  or failed upload does not burn a number.
</p>
<p>
  Because this counter is device-local rather than server-side, reinstalling restarts it. That
  is a deliberate simplicity trade: the number is a naming convenience, not an identifier —
  the RTDB push key is the identity.
</p>`,
    },
    {
      title: 'Serving attachments to a customer',
      html: `
<p>
  A customer looking at a shared quote cannot be handed a Firebase Storage download URL — that
  would leak a long-lived credentialed link. Instead the Express app proxies each asset behind
  the same share token, with a mode segment choosing inline view or download:
</p>
<pre>GET /q/:token/:mode(v|d)/:kind/:id
GET /i/:token/:mode(v|d)/:kind/:id</pre>
<p>
  The token is validated, the asset is confirmed to belong to that document, and only then is
  the bytes stream relayed. Revoking the quote revokes every attachment with it.
</p>`,
      caption: 'Attachment proxy',
      mermaid: `sequenceDiagram
  autonumber
  participant C as Customer browser
  participant FN as sharedQuoteAsset / sharedInvoiceAsset
  participant DB as RTDB share index + document
  participant ST as Cloud Storage

  C->>FN: GET /q/{token}/v/photo/{id}
  FN->>DB: resolve token → { uid, quoteId }
  FN->>DB: confirm the asset id is attached<br/>to THAT document
  alt not attached / token unknown
    FN-->>C: 404
  else authorised
    FN->>ST: read the object
    ST-->>FN: bytes
    FN-->>C: inline (v) or attachment (d)
  end`,
    },
  ],
});
