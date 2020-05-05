**Bug Fixes**:

* Address dc population bug where there was a 500 error if you had a dc string that included a space.

**New Operations**:

* Get a list of objects created or modified by a user with audit_responsibility.  See docs for more details.
* Find all objects matching your requested number of versions of a particular datastream.  See docs for more details.
* Find all objects that have no management restrictions (deny-management-functions).  See docs for more details.
* Find all exeptions to a specific XACML rule or action for all objects in a set.  See docs for more details.

**New Fedora Public Methods and Other Procs**:

* FedoraRequest.audit_responsibility(username): Returns a list of objects where a specific username has created or modified the object at some point.
* FedoraRequest.count_versions_of_datastreams(dsid): Returns pids with the total number of versions a specified datastream has.
* process_versions(): Requires a sequence of tuples with pids and number of versions are returns matches based on the specified operation and version value.