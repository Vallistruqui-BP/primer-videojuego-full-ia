# Vendored SDK

Heroic Labs nakama-godot v3.4.0, commit 14b7f7078a9822c15b0424624e4c883c87730cee.
Source: https://github.com/heroiclabs/nakama-godot/tree/14b7f7078a9822c15b0424624e4c883c87730cee
Only upstream addons directory and Apache-2.0 LICENSE copied. No upstream demos/art.
Reviewed @tool entry points before import; network adapters start requests only when called.
Default debug logging is explicitly disabled by the project client to avoid session logging.

Project patch, 2026-11-18: `client/NakamaHTTPAdapter.gd` sets
`HTTPRequest.accept_gzip = false` only on Web. The browser Fetch layer already
decodes Cloudflare gzip responses while retaining their Content-Encoding header.
Before the patch, public device authentication returned HTTP 200 but Godot failed
in stream_peer_gzip.cpp; direct browser Fetch decoded the same JSON successfully.
After the patch, the actual web game authenticated and joined a public WSS room.
Native request decompression is unchanged. Preserve this patch when upgrading SDK.
