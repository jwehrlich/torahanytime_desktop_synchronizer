# TorahAnytime Desktop Synchronizer

Allows for you to be able to synchronize lectures from speakers that you follow on TorahAnytime to your local machine.

### Version
1.0.0

### Requirements

In order to ensure that you can run this properly you will need to ensure that you have:

* Docker / Docker Compose

### Setup

**Setup .env**
```
# This can be found if you open developer tools and look at requests. It will show up
# as `uniqid` in the form data section of the request.
USER_ID="id-from-torah-anytime"
```

### Run

```sh
$ cd torahanytime_desktop_synchronizer
$ docker-compose up
```

License
----

MIT
