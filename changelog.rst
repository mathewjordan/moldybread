======================
Moldy Bread Change Log
======================

0.1.3 - Upcoming (Not Yet Tagged)
=================================

**Bug Fixes**:

* Progress bars did not really work in production.  This was due to how the newProgressBar constructor was being called.  By default, the constructor sets the length of the bar to be 100, but for us this may be much bigger or much smaller. This has been addressed and should scale and tick appropriately.
* Update metadata did not respect whether or not a datastream was verisoned.  Because of this, any update on an unversioned datastream would switch the datastream back to being versionable.  This has been addressed.
* Update metadata was counting a successful update twice.  This has been addressed.
* Address thrown exception from empty result set.

**New Operations**:

* Download all versions of a datastream with download all versions.  See docs for more details.

**New Fedora Public Methods**:

* FedoraRequest.get_content_models(): This returns a sequence of tuples with the pid (as a string) and a human readable content model (as a string).

0.1.2 - January 5, 2020
=======================

**New Operations**:

* Find Unique Datastreams:  You can get a list of unique datastreams that belong to a result set. See docs for more details.
* Validate Checksums: You can validate checksums for a specific datastream or all datastreams in a result set.  See docs for more details.

**New Fedora Public Methods**:

* FedoraRequest.get_datastream():  This returns a sequence of tuples with the pid (as a string) and a sequence of datastreams (as TaintedStrings) that belong to it. You can specify whether you want the entire datastream profile or just the datastreams (as HTML only) and specify a date that you want to base the request on. While this method is public, it is not currently called from the executable.
* FedoraRequest.validate_checksums(): See new operations for more details.
* FedoraRequest.find_distinct_datastreams(): See new operations for more details.

**Other**:

* Yaml config flag is now optional if you have a config/config.yml in the directory you call your executable from.
* FedoraRecord.get() now returns the response body of an HTTP request as a string or an empty string rather than true or false. This is mostly to help FedoraRequest.get_datastream().
* xmlhelper and parse_data()* has been added.

0.1.1 - January 1, 2020
=======================

**Documentation**:

* Build and release download instructions have been added.

**Operations**:

* Harvest Metadata and Harvest Metadata No Pages were renamed to Harvest Datastream to make things more agnostic. MODS is still default.
* Update Metadata and Delete Old Versions was added as a separate operation to optionally allow old versions of datastreams to be deleted on update.
* Change Object State allows you to batch change the state of all objects in a set to Active, Inactive, or Deleted.
* Find Objects Missing a Datastream was added to check for objects in a result set missing a particular datastream.
* Download Datastream Histories as XML was added to allow you to get a log of all events occuring on a datastream over time.
* Download Datastream at Date allows you to get a datastream at a specific date and time.
* For more information about any of this, read the docs.

**Other Notable Changes**:

* More extensions were added to cover expected mime types for datastreams.
* FedoraRecord.get() was renamed to FedoraRecord.download().  Download has the side affect of serializing to disk. A new get was created for returning values to other operations.

0.1.0 - December 17, 2020
=========================

* Initial release.