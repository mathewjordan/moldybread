Moldy Bread
===========

.. image:: https://travis-ci.org/markpbaggett/moldybread.png
   :alt: Travis Badge

An attempt to reimplement `whitebread <https://github.com/markpbaggett/whitebread/>`_ in `nim <https://nim-lang.org/>`_.

.. image:: https://markpbaggett.github.io/moldybread/moldy.gif
   :alt: Harvesting Metadata with No Pages with Moldy Bread
   

Installing and Building
-----------------------

**Installing the Release**

Moldy Bread is designed to be as portable as possible by being compiled in C.

The latest tagged release is available in `releases <https://github.com/markpbaggett/moldybread/releases>`_ and compiled with gcc. Depending on your architecture,
you may be able to use the binary available here. 

For security reasons, no authentication information is stored in the compiled version of the binary.  

For this reason, you must point at a config.yml file.  For more information about this, `review the documentation <https://markpbaggett.github.io/moldybread/moldybread.html#defining-a-configdotyml>`_.

**Building the Application**

If you are unable to use the release binrary, you can build a binary with the files in this repository.

1. First, follow the instrucitons here to install nim.
2. Make sure you set your PATH appropriately so that nim and nimble can be found.
3. Make sure you have a c compiler like gcc or musl (if not, you'll get an error in step 6).
4. git clone git@github.com:markpbaggett/moldybread.git
5. cd moldybread
6. nimble install

Documentation
-------------

Documentation for all packages and public procs and types are generated automatically and hosted on `GitHub Pages <https://markpbaggett.github.io/moldybread/moldybread.html>`_ after each commit.

Look here for instructions on how to use any piece of Moldy Bread.