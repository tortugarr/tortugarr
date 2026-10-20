# Security

## Report a security problem privately

Please **never** report a security problem in a public issue, a pull request or a discussion.

Report it privately on GitHub instead: open the repository's **Security** tab and choose
**Report a vulnerability**. This creates a private security advisory that only you and the
maintainers can see. We fix it there, and publish the advisory once a fixed release is out.

Please include what you found, how to reproduce it, and which version you used (the app's
Settings > About, and the server's Tortugarr version). Do not include real passwords or keys:
a description of where they appear is enough.

## What counts

For example:

- **Leaked keys or private data:** API keys, passwords, tokens, server addresses or build paths
  in the app, the plugin, the release files, the support bundle or this repository.
- **The Tortugarr plugin:** a way past its authentication, for example a non-admin or a
  signed-out user who can search, download, delete or reach the Sonarr, Radarr or Bazarr keys.
- **The installer:** anything that runs something unsafe, such as downloading and running code
  without checking it, files or folders others can write to, services open to the internet that
  should not be, or secrets saved where other users can read them.

Problems in Jellyfin, Seerr, Sonarr, Radarr, Prowlarr, Bazarr or the download clients
themselves belong with those projects. If you are not sure, report it here privately anyway.

## Supported versions

Only the latest release gets security fixes.
