---
name: jitter-watermark-remove
description: Remove Jitter.video watermarks from exported Lottie JSON files. Use when a user asks to remove a black jitter.video box, Jitter metadata, or Jitter export branding from a .json Lottie animation.
---

# Remove Jitter Watermark From Lottie JSON

Use this workflow for minified Lottie JSON exports from Jitter where the visible watermark is often vectorized, not a text layer.

## Rules

- Preserve the rest of the animation. Do not remove nearby app UI, logos, or product marks unless the user explicitly asks.
- Do not rely on `rg "jitter"` alone. The visible watermark can be converted into shape layers and may only appear as `meta.g`.
- Work structurally: parse JSON, remove the watermark layer subtree, remove only now-unused watermark assets, then validate all `refId` references.
- Verify visually against the original before finalizing. A wrong removal can look plausible in JSON but remove the wrong visible mark.

## Workflow

1. Save or access the original JSON before editing. If the file is tracked, use `git show HEAD:<path>` as the baseline.
2. Inspect likely literal references:

```bash
rg -n "Jitter|jitter|video|jitter.video" <lottie.json>
```

3. Summarize top-level layers and asset refs with Node:

```bash
node -e '
const fs=require("fs");
const p=process.argv[1];
const data=JSON.parse(fs.readFileSync(p,"utf8"));
console.log({assets:data.assets?.length,layers:data.layers?.length,w:data.w,h:data.h,meta:data.meta});
for (const l of data.layers.slice(-100)) {
  console.log(JSON.stringify({
    ind:l.ind, ty:l.ty, parent:l.parent, refId:l.refId, td:l.td, tt:l.tt,
    w:l.w, h:l.h, p:l.ks?.p?.k, shapes:l.shapes?.map(s=>s.ty)
  }));
}
' <lottie.json>
```

4. Identify the actual watermark by render position, not by guesswork. In the known Jitter export pattern, the black `jitter.video` box was a top-level precomp layer near the bottom-right, with a parent null object positioned around the lower-right corner. The wrong nearby target was a top-left app/logo mark.
5. Remove the selected watermark root and all descendants in the same layer array:

```js
const remove = new Set([WATERMARK_ROOT_IND]);
let changed = true;
while (changed) {
  changed = false;
  for (const layer of data.layers) {
    if (layer.parent != null && remove.has(layer.parent) && !remove.has(layer.ind)) {
      remove.add(layer.ind);
      changed = true;
    }
  }
}
data.layers = data.layers.filter((layer) => !remove.has(layer.ind));
```

6. Remove only assets that are exclusively referenced by the removed watermark. First collect `refId`s before and after removal; delete assets such as the watermark precomp and its nested text/vector asset only when no remaining layer references them.
7. Remove Jitter generator metadata if present:

```js
if (data.meta?.g === "https://jitter.video") delete data.meta.g;
if (data.meta && Object.keys(data.meta).length === 0) delete data.meta;
```

8. Validate JSON and dangling refs:

```bash
node -e '
const fs=require("fs");
const data=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const assetIds=new Set((data.assets||[]).map(a=>String(a.id)));
const refs=[];
function collect(layers,where){ for(const l of layers||[]) if(l.refId) refs.push({where,ind:l.ind,refId:String(l.refId)}); }
collect(data.layers,"root");
for(const a of data.assets||[]) collect(a.layers,`asset:${a.id}`);
const missing=refs.filter(r=>!assetIds.has(r.refId));
console.log({layers:data.layers.length, assets:data.assets?.length, missingRefs:missing.length, meta:data.meta ?? null});
if (missing.length) { console.error(missing.slice(0,20)); process.exit(1); }
' <lottie.json>
```

## Visual Verification

Create a temporary side-by-side render of original versus current with `lottie-web` when available. Embed JSON directly in the HTML to avoid `file://` fetch restrictions.

Checklist:

- The bottom-right black `jitter.video` box is gone.
- Nearby UI and app/logo marks are still present.
- The animation frame still renders.
- `rg "Jitter|jitter|video|jitter.video"` returns no matches unless the user wants to keep metadata.

For repo work, run the narrow changed-file verifier after the edit, such as `pnpm run verify:changed` when available.
