# Surfboard

A stremio alternative for tvOS

## Dev

### Secrets

Create a `Secrets.xcconfig` file in the root of the project. Add addon URLs with `https://` prefix (not `stremio://`):

```
CINEMETA=https:/$()/...
TORRENTIO=https:/$()/...
```

In Xcode, add `Secrets.xcconfig` to Project/surfboard/Info/Configuration/Debug.
