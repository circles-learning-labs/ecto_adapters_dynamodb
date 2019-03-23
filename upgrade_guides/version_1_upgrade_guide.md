# Upgrading from version 0.X.X -> 1.X.X

In version `1.X.X`, we have added migration support for DynamoDB's *pay-per-request* (AKA *on-demand*) billing. Thus, we no longer provide default provisioned throughput of `[1,1]` when creating tables and indexes via migrations. If any of your table/index creation files do not explicitly specify values for `provisioned_throughput`, you'll want to update those.

To create a *pay-per-request* table, you would add the `billing_mode: :pay_per_request` option to that table; you should not provide `provisioned_throughput` for *pay-per-request* tables, nor their indexes.

In order to make sure your local version of DynamoDB is up to date with the current production features, please use the latest release of DynamoDB local. As of spring 2019, the latest version is `1.11.477`, released on February 6, 2019.
