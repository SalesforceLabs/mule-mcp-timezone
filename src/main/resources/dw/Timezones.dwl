/*
 * Copyright (c) 2026, Salesforce, Inc.
 * SPDX-License-Identifier: Apache-2
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * Shared timezone lookup data for the Timezone MCP Server.
 *
 * Maps common city names/aliases to IANA timezone IDs. Imported by every
 * tool flow so the mapping lives in one place instead of being duplicated
 * per transform.
 */
%dw 2.0

/**
 * City name / alias -> IANA timezone ID. Keys are lower-cased so callers
 * should lower-case their input before looking up (see `resolve`).
 */
var cityMap = {
    "new york": "America/New_York",
    "nyc": "America/New_York",
    "los angeles": "America/Los_Angeles",
    "la": "America/Los_Angeles",
    "san francisco": "America/Los_Angeles",
    "sf": "America/Los_Angeles",
    "chicago": "America/Chicago",
    "denver": "America/Denver",
    "phoenix": "America/Phoenix",
    "houston": "America/Chicago",
    "dallas": "America/Chicago",
    "miami": "America/New_York",
    "seattle": "America/Los_Angeles",
    "boston": "America/New_York",
    "washington dc": "America/New_York",
    "dc": "America/New_York",
    "atlanta": "America/New_York",
    "toronto": "America/Toronto",
    "vancouver": "America/Vancouver",
    "mexico city": "America/Mexico_City",
    "sao paulo": "America/Sao_Paulo",
    "buenos aires": "America/Argentina/Buenos_Aires",
    "london": "Europe/London",
    "paris": "Europe/Paris",
    "berlin": "Europe/Berlin",
    "madrid": "Europe/Madrid",
    "rome": "Europe/Rome",
    "amsterdam": "Europe/Amsterdam",
    "zurich": "Europe/Zurich",
    "moscow": "Europe/Moscow",
    "istanbul": "Europe/Istanbul",
    "dubai": "Asia/Dubai",
    "abu dhabi": "Asia/Dubai",
    "riyadh": "Asia/Riyadh",
    "mumbai": "Asia/Kolkata",
    "delhi": "Asia/Kolkata",
    "bangalore": "Asia/Kolkata",
    "chennai": "Asia/Kolkata",
    "kolkata": "Asia/Kolkata",
    "karachi": "Asia/Karachi",
    "dhaka": "Asia/Dhaka",
    "bangkok": "Asia/Bangkok",
    "singapore": "Asia/Singapore",
    "kuala lumpur": "Asia/Kuala_Lumpur",
    "jakarta": "Asia/Jakarta",
    "hong kong": "Asia/Hong_Kong",
    "shanghai": "Asia/Shanghai",
    "beijing": "Asia/Shanghai",
    "taipei": "Asia/Taipei",
    "seoul": "Asia/Seoul",
    "tokyo": "Asia/Tokyo",
    "sydney": "Australia/Sydney",
    "melbourne": "Australia/Melbourne",
    "brisbane": "Australia/Brisbane",
    "perth": "Australia/Perth",
    "auckland": "Pacific/Auckland",
    "honolulu": "Pacific/Honolulu",
    "hawaii": "Pacific/Honolulu"
}

/**
 * Cities grouped by region, for the `list_timezones` tool. Display names
 * (title-cased) rather than lookup keys.
 */
var citiesByRegion = {
    "America": ["New York", "Los Angeles", "Chicago", "Denver", "Phoenix", "Houston", "Dallas", "Miami", "Seattle", "Boston", "Washington DC", "Atlanta", "Toronto", "Vancouver", "Mexico City", "Sao Paulo", "Buenos Aires"],
    "Europe": ["London", "Paris", "Berlin", "Madrid", "Rome", "Amsterdam", "Zurich", "Moscow", "Istanbul"],
    "Asia": ["Dubai", "Abu Dhabi", "Riyadh", "Mumbai", "Delhi", "Bangalore", "Chennai", "Kolkata", "Karachi", "Dhaka", "Bangkok", "Singapore", "Kuala Lumpur", "Jakarta", "Hong Kong", "Shanghai", "Beijing", "Taipei", "Seoul", "Tokyo"],
    "Australia": ["Sydney", "Melbourne", "Brisbane", "Perth"],
    "Pacific": ["Auckland", "Honolulu"]
}

/**
 * Resolve a user-supplied city name or timezone to an IANA timezone ID.
 * Falls back to the raw input (trimmed) so callers can pass an IANA ID
 * directly (e.g. "America/New_York").
 */
fun resolve(city: String | Null): String = do {
    var raw = city default ""
    ---
    cityMap[lower(raw)] default raw
}
