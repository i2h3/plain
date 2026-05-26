# PLAIN Standard Library Specification

Version 0.1 — Draft

All standard library functions follow the noun-form grammar rule: `noun of subject [preposition value]*`.

---

## Text

### Transformation

```plain
let upper    be uppercase of myText
let lower    be lowercase of myText
let clean    be trim of myText
let backward be reverse of myText
let result   be replacement of "hello" with "world" in myText
```

### Inspection

```plain
let n be length of myText
if myText is empty
if myText is not empty
```

### Boolean checks

```plain
if "hello" is in myText
if "hello" is not in myText
if "Hello" is prefix of myText
if "!" is suffix of myText
```

### Position

Returns a `list of number`. Empty when not found.

```plain
let findings be positions of "hello" in myText
```

### Extraction

```plain
let excerpt be substring of myText from 5 to 10
let letter  be character at 5 in myText
```

### Splitting

```plain
let items  be parts of myText by ","
let tokens be words of myText
let rows   be lines of myText
```

### Joining

```plain
let result be join of colours with ", "
let result be join of colours
```

### Conversion

`number from` and `decimal from` throw on invalid input.

```plain
let label be text from 42
let label be text from 3.14
let label be text from true

try
    let n be number from "42"
    let d be decimal from "3.14"
catch error
    print error->message
end
```

### Padding

```plain
let padded be left padding of myText to length 10 with "0"
let padded be right padding of myText to length 10 with "0"
let padded be left padding of myText to length 10
let padded be right padding of myText to length 10
```

---

## Number

```plain
let n be round of 3.7
let n be floor of 3.7
let n be ceiling of 3.7
let n be round of 3.14159 to places 2
let n be floor of 3.14159 to places 2
let n be ceiling of 3.14159 to places 2

let n be absolute of -42
let n be square root of 144
let n be power of 2 to 8
let n be remainder of 10 by 3

let n be minimum of scores
let n be maximum of scores
let n be minimum of 5 and 10
let n be maximum of 5 and 10
```

---

## Collections

### Transformation

```plain
let result   be sort of users by age
let result   be sort of users by descending age
let result   be sort of users by ascending age
let result   be filter of users where age > 18
let result   be filter of users where age > 18 and name is not "Admin"
let reversed be reverse of scores
let unique   be unique of scores
let combined be combination of listA and listB
```

### Aggregation

```plain
let total   be sum of scores
let average be average of scores
let count   be count of users where age > 18
```

### Finding

```plain
let first be first of users where age > 18
let last  be last of users where age > 18
```

### Checking

```plain
if any of users where age > 18
if all of users where age > 18
```

In `where` clauses, property names refer implicitly to the current item. No `item->` prefix is needed.

---

## Date and time

### The moment type

A `moment` is a unified date and time value. Time components are optional and default to midnight when omitted.

### Creation

```plain
let now       be current moment
let deadline  be moment of year 2025 month 6 day 1
let meeting   be moment of year 2025 month 6 day 1 hour 14 minute 30
let precise   be moment of year 2025 month 6 day 1 hour 14 minute 30 second 45
let timestamp be moment of year 2025 month 6 day 1 hour 14 minute 30 second 45 millisecond 500
```

### Extraction

```plain
let y  be year of myMoment
let mo be month of myMoment
let d  be day of myMoment
let h  be hour of myMoment
let mi be minute of myMoment
let s  be second of myMoment
let ms be millisecond of myMoment
```

### Arithmetic

```plain
let extended be moment 3 years after deadline
let extended be moment 6 months after deadline
let extended be moment 2 weeks after deadline
let extended be moment 5 days after deadline
let extended be moment 4 hours after deadline
let extended be moment 30 minutes after deadline
let extended be moment 45 seconds after deadline
let extended be moment 500 milliseconds after deadline
let earlier  be moment 2 hours before meeting
```

### Comparison

```plain
if deadline is before meeting
if meeting is after now
if deadline is same moment as meeting
```

### Difference

```plain
let days    be days between deadline and meeting
let hours   be hours between deadline and meeting
let minutes be minutes between deadline and meeting
let seconds be seconds between deadline and meeting
```

### Formatting and parsing

```plain
let label be text from deadline with format "yyyy-MM-dd"
let label be text from meeting with format "HH:mm"
let label be text from timestamp with format "yyyy-MM-dd HH:mm:ss"

try
    let d be moment from "2025-06-01"
    let d be moment from "01/06/2025" with format "dd/MM/yyyy"
catch error
    print error->message
end
```

---

## File system

### Path type

```plain
let p    be path of "/users/iva/documents/readme.txt"
let p    be path of "/users/iva" and "documents" and "readme.txt"

let n    be name of p
let ext  be extension of p
let full be full name of p
let dir  be parent of p

let home be home directory
let temp be temporary directory
let here be current directory

let p    be path of "/users/iva/readme.txt"
let t    be text from p
```

### File operations

All file operations are synchronous. They throw on failure. Wrap in a `task function` to avoid blocking the main thread.

```plain
let content be contents of file at p
write content to file at p
append content to file at p
let size    be size of file at p
let stamp   be modification date of p

if file exists at p
delete file at p
copy file from p to destination
move file from p to destination
```

### Directory operations

```plain
let items be contents of directory at p
if directory exists at p
create directory at p
delete directory at p
```

### Error handling

```plain
try
    let content be contents of file at p
catch error
    print "Could not read: " + error->message
end
```

---

## Networking

All network operations are synchronous. They throw on network failure. HTTP error status codes do not throw — check `status of result`. Wrap in a `task function` to avoid blocking the main thread.

### Requests

```plain
let result be response of get from "https://api.example.com/users"
let result be response of post from "https://api.example.com/users" with body content
let result be response of put from "https://api.example.com/users/1" with body content
let result be response of patch from "https://api.example.com/users/1" with body content
let result be response of delete from "https://api.example.com/users/1"
```

### Request headers

```plain
let result be response of get from "https://api.example.com/users" with header "Authorization" as "Bearer token"
```

### Response

```plain
let code   be status of result
let data   be body of result
let ctype  be header "Content-Type" of result

// Noun leads — no intermediate variable needed
let code   be status of get from "https://api.example.com/users"
let data   be body of get from "https://api.example.com/users"
```

### Error handling

```plain
try
    let result be response of get from "https://api.example.com/users"
    if status of result is not 200
        print "HTTP error: " + text from status of result
    end
catch error
    print "Network error: " + error->message
end
```

---

## JSON

### Flexible untyped access

```plain
let data    be parse json from body
let name    be text of "name" in data
let age     be number of "age" in data
let active  be bool of "active" in data
let address be object of "address" in data
let street  be text of "street" in address
let tags    be list of "tags" in data
let first   be text of item at 0 in tags
```

### Building JSON manually

```plain
let data be json object
set "name"   in data to "Iva"
set "age"    in data to 30
let tags     be json array with "admin", "user"
set "tags"   in data to tags
let encoded  be json of data
```

### The codable feature

See language specification section 10.5 for the full `codable` definition.

```plain
class user is codable
    property name as text
    property age  as number
end

let u       be user from json body
let encoded be json of u

// Key mapping
class user is codable
    property name as text   mapping "full_name"
    property age  as number mapping "user_age"
end
```

---

## Terminal

```plain
// Output
print "Hello, World!"
print "Something went wrong" to error output

// Styled output
print "Warning" with color "yellow"
print "Error"   with color "red" and style bold
print "Success" with color "green" and style bold
print "Detail"  with color "white" and style dim

// Input
let name be input with prompt "Enter your name: "
let raw  be input

// Terminal dimensions
let w be width of terminal
let h be height of terminal

// Clear
clear terminal
```

Available colors: `"black"`, `"red"`, `"green"`, `"yellow"`, `"blue"`, `"magenta"`, `"cyan"`, `"white"`

Available styles: `bold`, `italic`, `underline`, `dim`

---

## Environment

```plain
let token be value of environment "API_TOKEN"

if value of environment "DEBUG" is not nothing
    print "Debug mode"
end

let args  be arguments
let first be item at 0 in args

let os be operating system    // "windows", "macos", "linux"

exit with code 0
exit with code 1
```

---

## Random

```plain
let n    be random number
let n    be random number between 1 and 100
let d    be random decimal
let b    be random bool
let item be random item in myList
let new  be shuffle of myList
```
