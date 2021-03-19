# Changelog for Ecto.Adapters.DynamoDB v3.x.x

[v2.x.x -> v3.x.x upgrade guide](/upgrade_guides/version_3_upgrade_guide.md)

## v3.0.1

- Maintain backwards compatibility for Ecto versions 3.0 <= 3.4 - all major version 3 releases of Ecto should now be supported

## v3.0.0

### Enhancements

#### Configuration

- Per-repo configuration support

#### Dependencies

- Upgrade to and support for [Ecto](https://github.com/elixir-ecto/ecto) version 3.5 or higher (lower versions not supported by this release)
- Upgrade [ExAws.Dynamo](https://github.com/ex-aws/ex_aws_dynamo) to version 4 - recommend reviewing upgrade guide in that repo
- Upgrade Hackney to v1.17.3
