# Immich Photo Uploads

## immich-go CLI

The [`immich-go` cli](https://github.com/simulot/immich-go) is a CLI tool primarily used to upload photos exported from Google Photos via [Takeout](https://takeout.google.com).

## API key permission requirements

At minimum, your API key must have the following permissions:

- `asset.read`
- `asset.statistics`
- `asset.update`
- `asset.upload`
- `asset.copy`
- `asset.replace`
- `asset.delete`
- `asset.download`
- `album.create`
- `album.read`
- `albumAsset.create`
- `server.about`
- `stack.create`
- `tag.asset`
- `tag.create`
- `user.read`
- `job.create`
- `job.read`
