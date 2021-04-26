# Hamlet Engine Plugin - CMDB

This is a plugin for the hamlet engine which provides configuration database (cmdb) support including
- analysis
- config pipeline seeding
- migrations
- reports

It provides one provider

- **cmdb** - which implements the actual processing


## Implementation

The heart of the plugin is a set of general cmdb analysis routines, complemented by a seeder designed to include cmdb information into the config input pipeline.

The plugin also provides two entrances.

They should be run from the directory where the cmdbs repos has been checked out (which should also contain the `root.json` file that marks the root of the cmdb directory structure).

```$GENERATION_DIR/createTemplate.sh -i mock -e {entrance} -p cmdb -o {output-dir} -y "actions={ "|" separated list,{other name=value parameters}"```

- **cmdbinfo** - provides information reports about the available cmdbs

  Available parameters are
  - cmdbs - a `|` separated list of cmdbs to be processed via the `cmdbs` action
  - actions - a `|` separated list of actions to perform in the order they are provided
    - `layers` - show the layer values being used (default)
    - `lists` - show the layer values present in the cmdb
    - `context` - show the context filter being used to qualify content
    - `files` - show the files found in the cmdb
    - `content` - show the content available at the various layers
    - `cmdbs` - show the cmdbs discovered (filtered by any content of the `cmdbs` parameter)

  - filters - a `|` separated list of flags that control the level of output produced
    - `SuppressContent` - do not include file content in the match objects
    - `FlattenedFilenamesOnly` - only list filenames rather than the match objects (default)

  The context is constructed from the following layer values, with the layer value treated as a `|` separated list (to permit name and id to be provided - name is expected to be the first value and
  is what is shown via the "`inputs` action)
  - tenant (if none provided, and only one is found in the provided cmdbs, then the found one is used)
  - account
  - product
  - environment
  - segment

- **cmdbmigration** - performs cmdb upgrades and cleanups, replacing the existing bash process

  Available parameters
  - cmdbs - a `|` separated list of cmdbs to be processed
  - actions - a `|` separated list of actions to perform in the order they are provided
    - `upgrade` - perform cmdb upgrade (default)
    - `cleanup` - perform cmdb cleanup (default)
  - `upgrade` - version to upgrade to
  - `cleanup` - version to cleanup to
  - `dryrun` - don't perform the migration but produce the log to show what would be done if it were

## Installation

1. Clone this repository into your hamlet workspace
2. Add the path to the cloned location to the `GENERATION_PLUGINS_DIR` env var

    ```bash
    export GENERATION_PLUGINS_DIR="$(pwd);${GENERATION_PLUGINS_DIR}
    ```

3. The plugin will now be available to hamlet and can be included as a provider via `-p cmdb`.

## Testing

`test/test_snippets.sh` contains some example command lines used to test the provider both via `createTemplate.sh` and directly via `freemarker-wrapper.jar`. `test/test.ftl` contains a simple freemarker script to exercise the functions provided by the plugin.