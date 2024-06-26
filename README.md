# icaltoday

This is a small swift program that can print events
from your various calendars in JSON format. It is 
similar to [icalBuddy](https://github.com/ali-rantakari/icalBuddy),
which appears to 1) not be maintained and 2) not provide structured,
machine-readable output.

There are just
three commands. Maybe I'll add more later.

Authorize the app to access your calendars:

```sh
> icaltoday authorize
```

Get a list of your calendars:

```sh
> icaltoday calendars list
[
  "US Holidays",
  "MOJ",
  "Holidays in United States",
  "Consulting",
  "Family",
  "Work",
  "Contacts",
  "Kate",
  "Birthdays",
]
```

Get a list of events between two dates for two calendars:

```sh
> icaltoday events list 2022-10-18 2022-10-20 -c MOJ -c Kate
[
  {
    "attendeeEmails" : [
    ],
    "date" : "2022-10-19T12:00:00Z",
    "isToday" : false,
    "name" : "Xuff Dude",
    "uid" : "5dm6j7osehlv1c4@google.com",
    "uidAsBase64" : "NWb3NlaDVRtNmo31ZzBhNDUxa2FibHYxYzRAZ29vZ2xlLmNvbQ=="
  },
  {
    "attendeeEmails" : [
      "alex.booth@yale.edu",
      "farnorth@yale.edu",
      "kljensen@gmail.com",
      "kyle.jensen@yale.edu"
    ],
    "date" : "2022-10-19T14:15:00Z",
    "isToday" : false,
    "name" : "Startup chat",
    "uid" : "040000008200E1000000000000000010000000C00074C5B7101A82E008000000000B73BD888EC1D80EC9B1933E71464DB88DFA7A5289F629",
    "uidAsBase64" : "Dc0QzVCNzEwMUE4MkUwMDgwMDAwMDAwMDBCNzNCRDg4OEVDMUQ4MMDQwMDAwMDA4MjAwRTAwMDEwMDAwMDAwMDAwMDAwMDAwMTAwMDAwMDBDRUM5QjE5MzNFNzE0NjREQjg4REZBN0E1Mjg5RjYyOQ=="
  }
]
```

## Listing free times

You can list free time like the following:

```sh
> icaltoday availability list 2024-05-31 2024-05-31 12:00 16:00 --exclude-all-day -e Kathryn
[
  {
    "attendeeEmails" : [

    ],
    "endDate" : "2024-05-31T14:00:00-04:00",
    "isToday" : true,
    "name" : "free",
    "startDate" : "2024-05-31T01:00:00-04:00",
    "uid" : "AFE1F495-D0A1-4130-8B39-E01C5088B782",
    "uidAsBase64" : "QUZFMUY0OTUtRDBBMS00MTMwLThCMzktRTAxQzUwODhCNzgy"
  },
  {
    "attendeeEmails" : [

    ],
    "endDate" : "2024-05-31T16:00:00-04:00",
    "isToday" : true,
    "name" : "free",
    "startDate" : "2024-05-31T14:45:00-04:00",
    "uid" : "F61EAC5F-C4C9-4312-9BF7-6CC39041C8FB",
    "uidAsBase64" : "RjYxRUFDNUYtQzRDOS00MzEyLTlCRjctNkNDMzkwNDFDOEZC"
  }
]
```

Or, similarly with "natural dates":

```sh
./.build/debug/icaltoday availability list today today+1 12:00 17:00 --exclude-all-day -e Kathryn 
```

## Testing

Run `make test`.

## Building

On a mac, run `make` to build a debugging version. Run `make release` to build
a release version.

## Contributing

Please send a pull request!

## License

This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <http://unlicense.org/>