# Ecto.Adapters.DynamoDB

This is a partial implementation of an Elixir Ecto driver for Amazon's DynamoDB. Due to the fact that DynamoDB is a key value store designed for very high scale and Ecto is very much oriented to classic relational SQL databases there have been significant compromises in the implementation of this adaptor. Please keep in mind that while we are using it in production, it's currently in use in non critical systems and should be considered **beta**. Do not deploy it without thouroughly testing it for your use cases.

Before pushing commits, run `$ mix test` and confirm that processes are error-free.

### Special thanks to ExAws project
We use [ExAws](https://github.com/CargoSense/ex_aws/)' to wrap the actual DynamoDB API and requests. This project would not be possible without the extensive work in ExAws.

**This does mean you'll need to configure ExAws separately from the Ecto driver!**

Please see the ExAws documentation at:

[https://github.com/CargoSense/ex_aws/](https://github.com/CargoSense/ex_aws/)

### Design limitations - This driver is more 'plug and pray' than 'plug and play'
Amazon is a key value store. Ecto is very strongly influenced by relational SQL databases. This fundamental difference means that there are a lot of pretty normal things you'd expect to do in Ecto against an SQL database that you just can't do (or do efficiently) in DynamoDB. This means that if you expect to pick up your existing Ecto based app and just switch in DynamoDB, you're going to be disappointed - You still have to approach DynamoDB from a key/value store perspective.

Is DynamoDB the right choice for you?
It may not be.
Understand the DynamoDB limitations. It's designed for very high scale, throughput, and reliability - But to achieve this there are significant limitations with what you can do - And many things that you can do, but probably shouldn't.

A good starting point is Amazon's own documentation: 
[Amazon: Best Practices for DynamoDB](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/BestPractices.html)

Our philophy when creating this adaptor can generally be summed up as *Do what the end user will expect the adaptor to do, **unless** it's likely to break amazon performance or just won't work*. An example of this is our handling of 'scan' (see below).
Lastly, please read and understand how DynamoDB and its queries/indexes work. If you don't then a lot of the following behaviour is going to seem random, and you'll be frustrated trying to figure out why things don't work the way you expect them to. We've done our best to simplify what we can, but underneath it all, it's still DynamoDB.


#### How we use indexes
In DynamoDB, we can fetch individual records or batches of records *very* quickly if we know the primary key to look up, or the key of an indexed field. We CAN'T easily (for example), perform the following: `select * from people where name like 'Ali%'`.

We will try out best to parse the individual fields in the FROM portion of a request (Ecto Query), and find any DynamoDB index that exists on the table that can help us serve that query. This includes both HASH indexes, and HASH+RANGE indexes. (So the previous query might be made to work if you added the HASH criteria from HASH+RANGE index to the FROM.) If we do not find a full primary key or the HASH part of a composite primary key in the query WHERES, the adapter will opt for a DynamoDB scan; however, since a scan is the least efficient (and potentially most costly) way of querying DynamoDB, we have configured the adapter not to scan unless explicitly permitted either in configuration or inline.

The adaptor will query DynamoDB for a list of indexes and indexed fields on the table; and cache the results for use later.

As long as the FROM clause contains at least **one** HASH key from a DynamoDB index, a query will be constructed using our best guess at the most specific matching index (May not be the best index - Unlike an SQL server, we don't understand the data in the table, so will select a best guess rather than what is known to be optimal). Any other fields in the FROM criteria will be converted to DynamoDB filters as required to ensure you only get back the records you requested.

If there are NO matching indexes for the request, then by default, the query will give an error, unless 'scan' is enabled. Which leads us to:


#### Limited support for fetching all records. 'scan' disabled by default
Fetching arbitrary records based on a computed 'hash' of the primary key allows DynamoDB to scale across many partitions on many servers, resulting in high scalability and reliability. It also means that you can't do arbitrary queries based on unindexed fields.

Well, that's not quite true - It's just that you *really* probably don't want to be doing it. We do translate queries without any matching indexes to a DynamoDB `scan` operation - But this is not recommended against as it can easily burn all your read capacity. By default, these queries will fail. You can ensure they succeed by enabling the 'scan' option at the adapter level for all queries, or on an individual query basis. See 'scan' options below.

If you need to do this a lot, you're discarding all the benefits of DynamoDB - think carefully before you do.


#### No joins. Inner, outer, cross table, in-table, they're just not going to work
DynamoDB does not support joins. Thus neither do we. Pretty simple.
While it's technically possible for us to decompose the query into multiple individual requests against each table and then perform the join ourselves, this will likely result in very poor performance, and burning through excess read units to do so. It's better to construct these 'joins' manually using key/value lookups against indexes carefully chosen to preserve your predictable key/value store performance.

Having said that, it's possible that given decent indexes against each table that are guaranteed to return small subsets, we could add code to the adaptor to perform some simple joins. Feel free to submit a patch!

#### No transactions
Similar deal as with joins. DynamoDB does not support transactions, so neither do we. And, unlike joins where we could theoretically emulate them, there's simply no way to provide support for transactions in the adapter.

#### Limited sorting
DynamoDB can ONLY return sorted results when there is a matching HASH+RANGE index, where the desired sort key is the RANGE portion of the index. For this case, we support the **:scan_index_forward** inline [option](http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Query.html). However, writing queries like 'select * from person order by last_name limit 50' may or may not be practical - We'd have to retrieve every record from the table to do this. (See also *DynamoDB LIMIT & Paging* below.)

From DynamoDB's [Query API](http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Query.html):
>Query results are always sorted by the sort key value. If the data type of the sort key is Number, the results are returned in numeric order; otherwise, the results are returned in order of UTF-8 bytes. By default, the sort order is ascending. To reverse the order, set the ScanIndexForward parameter to false.

#### Update support
We currently support both `update` and `update_all` with some performance caveats. Since DynamoDB currently does not offer a batch update operation, `update_all` (and `update` if the full primary-key is not provided), we emulate it. The adaptor first fetches the query results to get all the relevant keys, then updates the records one by one (paging as it goes, see *DynamoDB LIMIT & Paging* below). Consequently, performance might be slower than expected due to multiple fetches followed by updates (plenty of network traffic). Also NOTE that this means that update operations are *not atomic*! Multiple concurrent updates to the same record from separate clients can race with each other, causing some updates to be silently lost.

#### DynamoDB LIMIT & Paging
By default, we configure the adapter to fetch all pages recursively for a DynamoDB `query` operation, and to *not* fetch all pages recursively in the case of a DynamoDB `scan` operation. This default can be overridden with the inline **:recursive** and **:page_limit** options (see below). We do not respond to the Ecto `limit` option; rather, we support a **:scan_limit** option, which corresponds with DynamoDB's [limit option](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Query.html#Query.Limit), limiting "the number of items that it returns in the result."

### Unimplemented Features
While the previous section listed limitations that we're unlikely to work around due to philosphical differences between DynamoDB as a key/value store vs an SQL relational database, there are some features that we just haven't implemented yet. Feel free to help out if any of these are important to you!

#### Adaptor.Migration & Adaptor.Storage
In the current release, we do not support creating tables and indexes in DynamoDB, nor do we support migrations to change them. You'll need to manually use the AWS DynamoDB web dashboard to create them, or another tool/scripting language.

#### Adaptor.Structure
Look, I have to be honest - I don't even know what this is for. So it's not going to work :)

#### Associations & Embeds
While we've not tested these, without joins, it's unlikely they work well (if at all).


### So what DOES work?
Well, basic CRUD really.
Get, Insert, Delete and Update. As long as it's simple queries against single tables, it's probably going to work. Anything beyond that probably isn't.

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

### Adapter options new to Ecto.Adapter.DynamoDB
See below *Configuration Options* section

## Caching

The adapter automatically caches its own calls to **describe_table** for retrieval of table information. We also offer the option to configure tables for scan caching (see configuration options below). To update the cache after making a change in a table, the cache offers two functions:

**Ecto.Adapters.DynamoDB.Cache.update_table_info!(table_name)**, *table_name* :: string

**Ecto.Adapters.DynamoDB.Cache.update_cached_table!(table_name)**, *table_name* :: string

## Configuration Options
The following options are configured during compile time, and can be altered in the application's configuration files ("config/config.exs", "config/dev.exs", "config/test.exs" and "config/test.exs").

For example, file "config/prod.exs":

```
config :ecto_adapters_dynamodb,
  insert_nil_fields: false,
  remove_nil_fields_on_update: true,
  cached_tables: ["colour"]
```
The above snippet will (1) set the adapter to ignore fields that are set to `nil` in the changeset, inserting the record without those attributes, (2) set the adapter to remove attributes in a record during an update where those fields are set to `nil` in the changeset, and (3) cache the first page of results for a call to `MyModule.Repo.all(MyModule.Colour)`, providing the cached result in subsequent calls. More details for each of those options follow.

**:scan_limit** :: integer, *default:* `100`

Sets the default limit on the number of records scanned when calling DynamoDB's **scan** command. This can be overridden by the inline **:scan_limit** option. Included as **limit** in the DynamoDB query. (Removed from queries during recursive fetch.)

**:scan_tables** :: [string], *default:* `[]`

A list of table names for tables pre-approved for a DynamoDB **scan** command in case an indexed field is not provided in the query *wheres*.

**:scan_all** :: boolean, *default:* `false`

Pre-approves all tables for a DynamoDB **scan** command in case an indexed field is not provided in the query *wheres*.

**:cached_tables** :: [string], *default:* `[]`

A list of table names for tables assigned for caching of the first page of results (without setting DynamoDB's **limit** parameter in the scan request).

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

## Inline Options

The following options can be passed during runtime in the Ecto calls. For example, consider a DynamoDB table with a composite index (HASH + RANGE):
```
MyModule.Repo.all(
  (from MyModule.HikingTrip, where: [location_id: "grand_canyon"]),
  recursive: false,
  scan_limit: 5
)
```
will retrieve the first five results from the record set for the indexed HASH, "location_id" = "grand_canyon", disabling the default recursive page fetch for queries. (Please note that without `recursive: false`, the adapter would ignore the scan limit.)

#### A Note About Ecto Query Parsing

Please note that in order for Ecto to recognize options, the preceding parameters have to be clearly delineated. The query is enclosed in parentheses and updates are enclosed in brackets, `[]`. For example, these options would be parsed,

`Repo.update_all((from ModelName, where: [attribute: value]), [set: [attribute: new_value]], option_field: option_value)`

but these would throw an error:

`Repo.update_all(from ModelName, where: [attribute: value], set: [attribute: new_value], option_field: option_value)`

#### **Inline Options:** *Repo.update*

**:range_key** :: {attribute_name_atom, value}, *default:* none

If the DynamoDB table queried has a composite primary key, an update query must supply both the `HASH` and the `RANGE` parts of the key. We assume that your Ecto model schema will correlate its primary id with DynamoDB's `HASH` part of the key. However, since Ecto will normally only supply the adapter with the primary id along with the changeset, we offer the range_key option to avoid an extra query to retrieve the complete key. The adapter will attempt to query the table for the complete key if the **:range_key** option is not supplied.

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

#### **Inline Options:** *Repo.update, Repo.update_all*

**:remove_nil_fields** :: boolean, *default:* set in configuration

Determines if fields in the changeset with `nil` values will be removed from the record/s or set to the DynamoDB `null` value.

### `is_nil` Queries

We support `is_nil` in query `wheres`. This will query DynamoDB for the attribute either set to `null` or to be missing from the record.  Please note that DynamoDB does not allow filtering for `null` or missing-attribute on attributes that are part of the current query's key conditions.

### DynamoDB `between` and Ecto `:fragment`

We currently only support the Ecto fragment of the form:

`from(m in Model, where: fragment("? between ? and ?", m.attribute, ^range_start, ^range_end)`

## Ecto Associations and Migrations

We currently do not support Ecto associations or migrations; we are looking forward to developing these features.

## Developer Notes

The **projection_expression** option is used internally during **delete_all** to select only the key attributes and is recognized during query construction.

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ecto_adapters_dynamodb](https://hexdocs.pm/ecto_adapters_dynamodb).



