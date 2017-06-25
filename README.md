# Ecto.Adapters.DynamoDB

This is a partial implementation of an Elixir Ecto adapter for Amazon's DynamoDB. Keep in mind that DynamoDB is a key-value store designed for very high scale, while the Ecto abstractions are primarily designed to work with relational databases. As such, we've had to make significant compromises in the implementation of this adapter to make it work. Please understand that while we are using it in production, it's currently in use in non-critical systems and should be considered **beta**. Do not deploy it without thouroughly testing it for your use cases.

If you wish to contribute, please run `$ mix test` and confirm that the test results are error-free before you push your commits. (Bonus points for improving our tests and adding your own tests for your changes. Patches with corresponding tests are more likely to be accepted, especially if they are significant.)

### Special thanks to ExAws project
We use [ExAws](https://github.com/CargoSense/ex_aws/)' to wrap the actual DynamoDB API and requests. This project would not be possible without the extensive work in ExAws.

**This does mean you'll need to configure ExAws separately from the Ecto adapter!**

Please see the ExAws documentation at:

[https://github.com/CargoSense/ex_aws/](https://github.com/CargoSense/ex_aws/)

### Design limitations
There are a lot of common things you can do in Ecto with a SQL database that you just can't do (or can't do efficiently) with DynamoDB. If you expect to pick up your existing Ecto-based app and just swap in DynamoDB, you're going to be disappointed. You still have to use this adapter the same way you would approach using a key-value store, and avoid the kinds of patterns you'd use with a relational database.

**Is DynamoDB the right choice for you?**
It may not be.
Understand the DynamoDB limitations. It's designed for very high scale, throughput, and reliability. As a result of this design, there are many kinds of operations that are impossible. Other things are technically possible but not advisable, due to high costs in terms of performance and/or money.

A good starting point is Amazon's own documentation:
[Amazon: Best Practices for DynamoDB](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/BestPractices.html)

Our philophy when creating this adapter can generally be summed up as:

 *Try to do what the end user will expect the adapter to do, **unless** it's likely to ruin DynamoDB's performance.*

An example of this is our handling of table scans (see below).
Lastly, please read and understand how DynamoDB and its queries and indexes work. If you don't, then a lot of the following behaviour is going to seem random, and you'll be frustrated trying to figure out why things don't work the way you expect them to. We've done our best to simplify what we can, but underneath it all, it's still DynamoDB.


#### How we use indexes
In DynamoDB, we can fetch individual records or batches of records *very* quickly if we know the primary key to look up, or the key of an indexed field. We **can't** easily perform queries which don't have a simple key or ID to look up:

Will work: (note that this will be a *case sensitive* match as well.)

`select * from people where name = 'ALICE'`

Won't Work:

`select * from people where name like 'Ali%'`

(Obviously these are SQL queries, not Ecto queries, but the above examples just provide a general illustration of what sorts of limitations to expect.)

We will try our best to parse queries and find any relevant DynamoDB indexes that exists. (This includes both HASH indexes, and HASH+RANGE indexes.) As long as the FROM clause contains at least **one** HASH key from a DynamoDB index, a query will be constructed using our best guess at the most specific matching index. (This may not be the best index - unlike a SQL server, we don't understand the data in the table, so the adapter may have to guess.) Any other fields in the FROM criteria will be converted to DynamoDB filters as required to ensure you only get back the data you requested. We also support `is_nil` in queries. This will test whether the attribute is either set to `null` *or* whether the attribute is missing from the record altogether. Please note that DynamoDB does not allow for this type of filtering on attributes that are being queried against, whether in the primary key or in a secondary index.

If we do not find any matching table index for the query (either a HASH key of an index or the HASH part of a composite HASH+RANGE key), the query will fail by default. It is possible to override this behaviour and have the adapter perform a dynamoDB *scan* instead. Since scans do not scale well, they can potentially be very costly with large data sets, and we have configured the adapter not to scan unless scanning is explicitly enabled. This can be done via global configuration options, or inline as an option to 'Repo.all' and other query functions. See the section below on **scan** for more info.

The adapter will query DynamoDB for a list of indexes and indexed fields on the table, and by default it will cache the results to avoid the overhead of repeatedly pulling the same lists of indexes on every query. This does mean that if you update the indexes on a table in DynamoDB, you will need to execute the **Ecto.Adapters.DynamoDB.Cache.update_table_info!** function or restart the adapter.


#### Limited support for fetching all records. 'scan' disabled by default
Fetching records based on a hash of the primary key allows DynamoDB to distribute its data across many partitions on many servers, resulting in high scalability and reliability. It also means that you can't do arbitrary queries based on unindexed fields.

Well, that's not quite true, but running queries against un-indexed fields is usually a terrible idea. We can translate queries without any matching indexes to a DynamoDB `scan` operation, but this is not recommended as it can easily burn through all your read capacity. By default, attempting to perform these kinds of queries will raise an error. You can allow them to succeed by enabling the 'scan' option at the adapter level for all queries, or by specifying the corresponding option on individual queries. See 'scan' options below for more information.

If you need to do this a lot, you're losing most of the benefits of DynamoDB, so think carefully before you do.


#### No joins
DynamoDB does not support joins. Thus, neither do we. Pretty simple.
While it's technically possible for us to decompose the query into multiple individual requests against each table and then perform the join ourselves, this will likely result in very poor performance, and burning through excess read units to do so. It's better to construct these 'joins' manually using key/value lookups against indexes carefully chosen to preserve your predictable key/value store performance.

This is one of those things that are technically possible, but would result in very unpredictable performance that could drag down your entire app, reducing or eliminating any benefit from DynamoDB. You're probably better off using another DB if this is a requirement.

That said, for very simple joins that match a limited number of keys where all the relevant fields are indexed, joins could probably be emulated pretty reasonably. We'd entertain the notion of accepting a patch for this, if anyone wants to go to the trouble, and if the code contains some reasonable safeguards to avoid executing big, expensive joins by accident. It would be tricky though, and it's certainly not a priority for us right now.


#### No transactions
Similar deal as with joins. DynamoDB does not support transactions, so neither do we. And, unlike joins where we could theoretically emulate them, there's simply no way to provide support for transactions in the adapter.


#### Limited sorting
DynamoDB can ONLY return sorted results if there is a matching HASH+RANGE index where the desired sort key is the RANGE portion of the index. In this case we support the **:scan_index_forward** [option](http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Query.html) as a parameter to Repo queries. However, writing queries like 'select * from person order by last_name limit 50' may not be practical; we'd have to retrieve every record from the table to do this. (See also *DynamoDB LIMIT & Paging* below.)

From DynamoDB's [Query API](http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Query.html):
>Query results are always sorted by the sort key value. If the data type of the sort key is Number, the results are returned in numeric order; otherwise, the results are returned in order of UTF-8 bytes. By default, the sort order is ascending. To reverse the order, set the ScanIndexForward parameter to false.


#### Update support
We currently support both `update` and `update_all` with some performance caveats. Since DynamoDB currently does not offer a batch update operation, we emulate it in `update_all` (and `update` if the full primary-key is not provided). The adapter first fetches the query results to get all the relevant keys, then updates the records one by one (paging as it goes, see *DynamoDB LIMIT & Paging* below). Consequently, performance might be slower than expected due to the need to execute individual fetches followed by individual inserts. Also please note that this means that update operations are *not atomic*! Multiple concurrent updates to the same record can race with each other, causing some updates to be silently lost.

All of these caveats can be especially pernicious if you're performing eventually consistent reads, as is the default for DynamoDB: you could easily write a record, then attempt to perform an update, which could read from a zone that hasn't received your write yet. This would cause the update's fetch to return not_found, with the update data then overwriting your original write! Thus, even if a single client synchronously does a write, waits for success, then does an update, you may still experience data loss! So, the moral of the story is, be really careful with updates; and you may want to use consistent reads unless you really know what you're doing (see the `consistent_read` option for more info).

#### DynamoDB LIMIT & Paging
By default, we configure the adapter to fetch all pages recursively for a DynamoDB `query` operation, and to *not* fetch all pages recursively in the case of a DynamoDB `scan` operation. This default can be overridden with the inline **:recursive** and **:page_limit** options (see below). We do not respond to the Ecto `limit` option; rather, we support a **:scan_limit** option, which corresponds with DynamoDB's [limit option](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Query.html#Query.Limit), limiting "the number of items that it returns in the result."

### Unimplemented Features
While the previous section listed limitations that we're unlikely to work around due to philosphical differences between DynamoDB as a key/value store vs an SQL relational database, there are some features that we just haven't implemented yet. Feel free to help out if any of these are important to you!

#### Adapter.Migration & Adapter.Storage
In the current release, we do not support creating tables and indexes in DynamoDB, nor do we support migrations to change them. You'll need to manually use the AWS DynamoDB web dashboard to create them, or another tool/scripting language.

#### Adapter.Structure
Look, I have to be honest - I don't even know what this is for. So it's not going to work :)

#### Associations & Embeds
While we've not tested these, without joins it's unlikely they work well (if at all).


### So what DOES work?
Well, basic CRUD really, which is all you should really expect from a key/value store :).

Get, Insert, Delete and Update. As long as it's simple queries against single tables, it's probably going to work. Anything beyond that probably isn't. All of the following Ecto functions should work to some extent, if not necessarily in every scenario.

* all/2
* delete/2
* delete!/2
* delete_all/2
* get/3
* get!/3
* get_by/3
* get_by!/3
* insert/2
* insert!/2
* insert_all/3
* one/2
* one!/2
* update/2
* update!/2
* update_all/3


## Installation

We will be making the package available [Hex](https://hex.pm/) soon. Once available, the package can be installed
by adding `ecto_adapters_dynamodb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:ecto_adapters_dynamodb, "~> 0.1.0"}]
end
```

Otherwise, to fetch from GitHub:

```elixir
def deps do
  [{:ecto_adapters_dynamodb, git: "https://github.com/circles-learning-labs/ecto_adapters_dynamodb", branch: "master"}]
end
```


### Configuration
Configuring a repository to use the DynamoDB ecto adapter is pretty similar to most other Ecto adapters. Set the adapter option in the Repo configuration to 'Ecto.Adapters.DynamoDB', and remove the database/user/password/etc options - you'll need to configure the equivalent options in ExAws instead (AWS access key, host and secret).


Include the repo module that's configured for the adapter among the project's Ecto repos. File, "config/config.exs"
```
  config :my_app, ecto_repos: [MyModule.Repo]
```
Include the adapter in the project's applications list. File, "mix.exs":

```
  def application do
    [...
    applications: [..., :ecto_adapters_dynamodb, ...]
    ...
  end
```

#### Development
For development, we use the [local version](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html) of DynamoDB, and some dummy variable assignments.

File, "config/dev.exs":
```               
config :my_app, MyModule.Repo,
  adapter: Ecto.Adapters.DynamoDB,
  database: "database_name",
  username: "username",
  password: "",                         
  hostname: "localhost"
```

#### Production
File, "config/prod.exs"
```
config :my_app, MyModule.Repo,
  adapter: Ecto.Adapters.DynamoDB
```
Specific DynamoDB access information will be in the configuration for ExAws.


### ExAws
Don't forget to configure ExAws as separate application per their documentation

### Other adapter options
The following are other application env options, which can be specified e.g. as follows in your project's config files:

```
config :ecto_adapters_dynamodb,
  insert_nil_fields: false,
  remove_nil_fields_on_update: true,
  cached_tables: ["colour"]
```
The above snippet will (1) set the adapter to ignore fields that are set to `nil` in the changeset, inserting the record without those attributes, (2) set the adapter to remove attributes in a record during an update where those fields are set to `nil` in the changeset, and (3) cache scan results from the "colour" table, providing the cached result in subsequent calls. More details for each of those options follow.

#### `nil` value handling options

**:insert_nil_fields** :: boolean, *default:* `true`

Determines if fields in the changeset with `nil` values will be inserted as DynamoDB `null` values or not set at all. This option is also available inline per query. Please note that DynamoDB does not allow setting indexed attributes to `null` and will respond with an error. It does allow removal of those attributes.

**:remove_nil_fields_on_update** :: boolean, *default:* `false`

Determines if, during **Repo.update** or **Repo.update_all**, fields in the changeset with `nil` values will be removed from the record/s or set to the DynamoDB `null` value. This option is also available inline per query.

#### Logging Configuration
The adapter's logging options are configured during compile time, and can be altered in the application's configuration files ("config/config.exs", "config/dev.exs", "config/test.exs" and "config/test.exs"). 

We provide a few informational log lines, such as which adapter call is being processed, as well as the table, lookup fields, and options detected. Configure an optional log path to have the messages recorded on file.

**:log_levels** :: [log-level-atom], *default:* `[:info]`, *log-level-atom can be :info and/or :debug*

**:log_colors** :: %{log-level-atom: IO.ANSI-color-atom}, *default:* `info: :green, debug: :normal`

**:log_path** :: string, *default:* `""`

#### Scan-related options
**:scan_tables** :: [string], *default:* `[]`

A list of table names for tables pre-approved for a DynamoDB **scan** command in case an indexed field is not provided in the query *wheres*. By default, scans are completely disabled on all tables. Use this option carefully; you may be better off using the inline query options to make sure you only perform table scans when you explicitly expect to do so.

**:scan_limit** :: integer, *default:* `100`

Sets the default limit on the number of records scanned when calling DynamoDB's **scan** command. This can be overridden by the inline **:scan_limit** option. Included as **limit** in the DynamoDB query. (This option does not apply to queries performing recursive fetches.)

**:scan_all** :: boolean, *default:* `false`

Pre-approves all tables for a DynamoDB **scan** command in case an indexed field is not provided in the query *wheres*.

**:cached_tables** :: [string], *default:* `[]`

A list of table names for tables assigned for caching of the first page of results (without setting DynamoDB's **limit** parameter in the scan request). For a set table, call `Repo.all(Model)` to cache the first page of results. To override the caching for a table in this list, and perform a regular scan with associated inline options (see below), provide an additional `scan: true` option with the query; for example, `Repo.all(Model, scan: true, recursive: true)`.

## Inline Options

The adapter only supports our custom inline options; assume the regular inline options provided by Ecto will be ignored. The following options can be passed during runtime in the Ecto calls. For example, consider a DynamoDB table with a composite index (HASH + RANGE):
```
MyModule.Repo.all(
  (from MyModule.HikingTrip, where: [location_id: "grand_canyon"]),
  recursive: false,
  scan_limit: 5
)
```
will retrieve the first five results from the record set for the indexed HASH, "location_id" = "grand_canyon", disabling the default recursive page fetch for queries. (Please note that without `recursive: false`, the adapter would ignore the scan limit.)

#### **Inline Options:** *Repo.update*, *Repo.delete*

**:range_key** :: {attribute_name_atom, value}, *default:* none

If the DynamoDB table queried has a composite primary key, an update or delete query must supply both the `HASH` and the `RANGE` parts of the key. We assume that your Ecto model schema will correlate its primary id with DynamoDB's `HASH` part of the key. However, since Ecto will normally only supply the adapter with the primary id along with the changeset, we offer the range_key option to avoid an extra query to retrieve the complete key. The adapter will attempt to query the table for the complete key if the **:range_key** option is not supplied.

#### **Inline Options:** *Repo.all, Repo.update_all, Repo.delete_all*

**:scan_limit** :: integer, *default:* none, except configuration default applies to the DynamoDB `scan` command

Sets the limit on the number of records scanned in the current query. Included as **limit** in the DynamoDB query.

**:scan** :: boolean, *default:* `false` (also depends on scan-related configuration)

Approves a DynamoDB **scan** command for the current query in case an indexed field is not provided in the query *wheres*.

**:exclusive_start_key** :: [key_atom: value], *default:* none

Adds DynamoDB's **ExclusiveStartKey** to the current query, providing a starting offset.

**:scan_index_forward** :: boolean, *default:* none

Adds DynamoDB's **ScanIndexForward** to the current query, specifying ascending (true/default) or descending (false) traversal of the index. (Quoted from DynamoDB's [documentation](http://docs.aws.amazon.com/sdkfornet1/latest/apidocs/html/P_Amazon_DynamoDBv2_Model_QueryRequest_ScanIndexForward.htm).)

**:consistent_read** :: boolean, *default:* none

If set to `true`, then the operation uses strongly consistent reads; otherwise, eventually consistent reads are used. Strongly consistent reads are not supported on global secondary indexes. If you query a global secondary index with ConsistentRead set to true, you will receive an error message. (Quoted from DynamoDB's [documentation](http://docs.aws.amazon.com/sdkfornet1/latest/apidocs/html/P_Amazon_DynamoDBv2_Model_QueryRequest_ConsistentRead.htm).)

**:recursive** :: boolean, *default:* `true`, except for DynamoDB `scan` where default is `false`

Fetches all pages recursively and performs the relevant operation on results in the case of *Repo.update_all* and *Repo.delete_all*

**:page_limit** :: integer, *default:* none

Sets the maximum number of pages to access. The query will execute recursively until the page limit has been reached or there are no more pages (overrides **:recursive** option).

#### QueryInfo agent

**:query_info_key** :: string, *default:* none

If you would like the query information provided by DynamoDB (for example, to retrieve the LastEvaluatedKey even when no results are returned from the current page), include the option, **query_info_key:** *key_string*.

After the query is completed, retrieve the query info from the adapter's **QueryInfo** agent (the key is automatically deleted from the agent upon retrieval):

`Ecto.Adapters.DynamoDB.QueryInfo.get(key_string)`

The returned map corresponds with DynamoDB's return values:

`%{"Count" => 10, "LastEvaluatedKey" => %{"id" => %{"S" => "6814"}}, "ScannedCount" => 100}`

**Ecto.Adapters.DynamoDB.QueryInfo.get_key** provides a 32-character random string for convenience.

#### **Inline Options:** *Repo.insert, Repo.insert_all*

**:insert_nil_fields** :: boolean, *default:* set in configuration

Determines if fields in the changeset with `nil` values will be inserted as DynamoDB `null` values or not set at all.

**:overwrite** :: boolean, *default:* none

By default, the adapter will provide the condition expression, `attribute_not_exists(PARTITION_KEY_ATTRIBUTE)` with the DynamoDB query, failing to insert if the record already exists. To perform an uncoditional insert, possibly overwriting an existing record, provide the option `overwrite: true` in the insert query.

#### **Inline Options:** *Repo.update, Repo.update_all*

**:remove_nil_fields** :: boolean, *default:* set in configuration

Determines if fields in the changeset with `nil` values will be removed from the record/s or set to the DynamoDB `null` value.

### DynamoDB `between` and Ecto `:fragment`

We currently only support the Ecto fragment of the form:

`from(m in Model, where: fragment("? between ? and ?", m.attribute, ^range_start, ^range_end)`

## Caching

The adapter automatically caches its own calls to **describe_table** for retrieval of table information. We also offer the option to configure tables for scan caching. To update the cache after making a change in a table, the cache offers two functions:

**Ecto.Adapters.DynamoDB.Cache.update_table_info!(table_name)**, *table_name* :: string

This re-fetches and caches the index data for the given table.

**Ecto.Adapters.DynamoDB.Cache.update_cached_table!(table_name)**, *table_name* :: string

This runs a scan against the given table and updates the in-memory cached copy of it.

## Developer Notes

The **projection_expression** option is used internally during **delete_all** to select only the key attributes and is recognized during query construction.

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ecto_adapters_dynamodb](https://hexdocs.pm/ecto_adapters_dynamodb).



