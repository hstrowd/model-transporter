# README

## Purpose

__FOR DEVELOPMENT ONLY. DO NOT USE THIS IN A PRODUCTION ENVIRONMENT.__

This gem extracts the logic required to traverse an ActiveRecord dependency tree and migrate records between two data sources. The intention is to allow us to easily move data into a development environment in a consistent manner across a series of interrelated services.


## Rake Task

This gem adds a ```model_transport:load_from``` rake task. This tasks takes advantage of the following environment variables, when present:

* ```TRANSPORTED_RECORDS_FILE```: The path to a file containing the records that have been or should be transported. This file should be a JSON formatted hash in which the keys are Model name and the values are record IDs from the source data store. For example, the following would be a valid sample of the content in this file:

```javascript
{
  "User": [ 123, 234 ],
  "Post": [ 456, 567, 987 ]
}
```

* ```SOURCE_DB_ADAPTER```: The name of the adapter to be used when connecting to the source data store.
* ```SOURCE_DB_NAME```: The name of the database to be used when connecting to the source data store.
* ```SOURCE_DB_HOST```: The host server for the source data store.
* ```SOURCE_DB_USER```: The username to be used when connecting to the source data store.
* ```SOURCE_DB_PASSWORD```: The password to be used when connecting to the source data store.
* ```DEBUG```: An indicator for whether or not debug output should be printed. Values of ```true```, ```TRUE```, ```t```, ```T```, or ```1``` will result in debug output being printed.

The output of this rake task will included an updated version of the contents of the ```TRANSPORTED_RECORDS_FILE``` with the newly transported records merged into it.


### Usage Notes

For the first service's transport, the ```TRANSPORTED_RECORDS_FILE``` content should contain the records that need to be transported. For all subsequent services, the ```TRANSPORTED_RECORDS_FILE``` content should be the result of the previous service's transport.

The following is an example of how this rake task can be invoked:

```bash
$ bundle exec rake model_transport:load_from TRANSPORTED_RECORDS_FILE=/tmp/transported_records.json SOURCE_DB_NAME=myapp_db SOURCE_DB_HOST=staging.myapp.com SOURCE_DB_USER=myapp_user SOURCE_DB_PASSWORD=myapp_password
```


## ActiveRecord Updates

This gem adds a ```transport``` method to all ```ActiveRecord::Base``` instances. This method expects to be passed at least one argument defining the target database into which the record is being transported.

A second parameter can also be provided to identify any records that are in the process of being migrated but have not yet been written into the target date store. The structure of this argument should be a hash with class name keys and values that are hashes that map the source record ID to the target record ID. For instance the following value could be provided:

```json
{
  "User": [1, 2],
  "Post": [4, 5, 6]
}
```

This would indicate that the User models with ID 1 and 2 as well as the Post models with IDs 4, 5, and 6 are all in the process of being migrated. In this case if the traversal encounters one of these records it will not try to transport it and instead treat this as a base case for the recursion and begin walking back up the chain.

This method is invoked from within the rake task and was not designed to be used outside of this environment.


## Installation

To install this gem into a Rails or Rack application take the following steps:

1. Add the ```model-transporter``` gem to your ```Gemfile```.
    * I recommend only adding this to development and/or test groups.
1. Configure the ```Transporter``` in the appropriate environments.
    * This is done by calling the ```configure_transporter``` method and passing it a block that takes a configuration object allowing your to configure it's behavior.
    * My suggestion is to create a file like the following that takes care of this configuration and require it only in the appropriate environments:

        ```ruby
        require 'transporter'

        # Defines the logic used to identify the records to be transported, based on the records that have
        # already been transported from other services.
        Transporter.configure_transporter do |config|
          config.configure_records_to_transport do |scope, prev_transported_records|
            next unless prev_transported_records.is_a?(Hash) || prev_transported_records['User'].nil?
            transported_users = prev_transported_records['User']
            travelsable_post_associations = [
              :comments,
	      :tags
            ]
            travelsable_comment_associations = [ ]  # Don't pull comment authors.

            scope.configure_class(User, { ids: transported_users })
            scope.configure_class(Post, { associations: travelsable_post_associations })
            scope.configure_class(Comment, { associations: travelsable_comment_associations })
          end
        end
        ```

    * The config object exposes the ```configure_records_to_transport``` method to allow you to identify the appropriate records to extract from the source data store.
    * The arguments passed into this block are the following
        * A scope definition object (see explanation below).
	* The previously transported set of records (see the ```TRANSPORTED_RECORDS_FILE``` specification above).
    * The scope definition object exposes a ```configure_class``` method, allowing you to configure the model traversal that will be performed on a per class basis. This method expects the following two parameters:
        * The ActiveRecord class to be configured.
	* A hash defining the traversal logic to be used. The following keys are currently supported:
	    * ids:
	        * The set of IDs that will be transported from the source data store to the target data store.
		* This serves as the seed data for the transport.
		* This is also used to limit the scope of the transport.
		* If the traversal encounters an instance of this classes with an ID not in this set, it will not export that record.
	    * associations:
	        * The associations on this model, as symbolized association names, that should included in the traversal.
		* All other associations will be skipped. This allows you to limit the scope of the traversal and prevent the transport from pulling in the entire data store.
    * All models will be connected to the source data store at the time of executing this block, so you do not need to handle this yourself.
1. Pull the ```model-transporter``` rake tasks into the application.
    * This can be done by adding the following logic to the ```Rakefile``` for the application:

        ```ruby
        spec = Gem::Specification.find_by_name 'model-transporter'
        load "#{spec.gem_dir}/lib/tasks/model_transporter.rake"
        ```


## Notes/Warnings

* __CAUTION:__ This gem was designed for and is intended to be used in development and test environments only.

