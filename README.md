# Surfboard

A stremio alternative for tvOS

## Dev

### Secrets

Create a `Secrets.xcconfig` file in the root of the project. Add the following variables:

```
TORRENTIO_BASE_URL=https:/$()/torrentio.strem.fun/debridoptions=nodownloadlinks,nocatalog|realdebrid=<YOUR_REALDEBRID_KEY>
```

In Xcode, add `Secrets.xcconfig` to Project/surfboard/Info/Configuration/Debug.
