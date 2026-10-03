# Service Guide Documentation

This guide provides comprehensive documentation for all tradesperson services available in the FixItFelix app.

**Version:** 3.0
**Last Updated:** 2026-02-25
**Total Services:** 25 (24 trades + Other)

---

## Table of Contents

**Home Services**
1. [Plumber](#1-plumber)
2. [Electrician](#2-electrician)
3. [Painter](#3-painter)
4. [Carpenter](#4-carpenter)
5. [Handyman](#5-handyman)

**Building & Construction**
6. [Roofer](#6-roofer)
7. [Builder](#7-builder)
8. [Plasterer](#8-plasterer)
9. [Tiler](#9-tiler)
10. [Glazier](#10-glazier)
11. [Scaffolder](#11-scaffolder)
12. [Welder](#12-welder)

**Outdoor & Garden**
13. [Gardener](#13-gardener)
14. [Landscaper](#14-landscaper)
15. [Tree Surgeon](#15-tree-surgeon)

**Heating & Gas**
16. [Central Heating](#16-central-heating)
17. [Boiler Repair](#17-boiler-repair)
18. [Gas Engineer](#18-gas-engineer)
19. [HVAC Technician](#19-hvac-technician)

**Kitchen & Bathroom**
20. [Kitchen Fitter](#20-kitchen-fitter)

**Security**
21. [Locksmith](#21-locksmith)

**Automotive**
22. [Mechanic](#22-mechanic)

**Cleaning**
23. [Cleaner](#23-cleaner)

**Personal Care**
24. [Hairdresser](#24-hairdresser)

**Other**
25. [Other Services](#25-other-services)

---

## JSON Structure Guide

Each service JSON file follows this enhanced structure:

```json
{
  "service": "service_id",
  "title": "Main question displayed to user",
  "subtitle": "Helper text for context",
  "categories": [
    {
      "id": "unique_id",
      "name": "Display Name",
      "icon": "icon_name",
      "description": "What this category covers",
      "urgent": true/false,
      "requiresDescription": true/false,
      "options": [
        {
          "id": "option_id",
          "name": "Option Name",
          "description": "What this option is for",
          "options": [
            {"id": "sub_id", "name": "Sub Option"}
          ]
        }
      ]
    }
  ]
}
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `service` | string | Yes | Unique service identifier |
| `title` | string | Yes | Main question shown to user |
| `subtitle` | string | Yes | Helper text below the title |
| `categories` | array | Yes | List of service categories |
| `id` | string | Yes | Unique category/option identifier |
| `name` | string | Yes | Display name for UI |
| `icon` | string | No | LucideIcon identifier for UI |
| `description` | string | No | Explains what the category/option covers |
| `urgent` | boolean | No | Marks emergency categories (shows priority) |
| `requiresDescription` | boolean | No | Requires user text input |
| `options` | array | No | Sub-options (can be nested up to 3 levels) |

---

## Home Services

### 1. Plumber

**File:** `plumber.json`
**Key:** `plumber`
**Title:** "What plumbing help do you need?"
**Subtitle:** "Select the area that best describes your issue"

#### Categories
- **Heating & Hot Water** — Boilers, radiators, and hot water systems
- **Bathroom Plumbing** — Showers, baths, toilets and basins
- **Kitchen Plumbing** — Sinks, dishwashers and kitchen taps
- **Pipes & Leaks** — Leaking, burst or frozen pipes
- **Blockages** — Blocked drains, toilets and sinks
- **Outdoor Plumbing** — External taps, drainage and stopcocks
- **Emergency** (Urgent) — Burst pipes, major leaks, no water

---

### 2. Electrician

**File:** `electrician.json`
**Key:** `electrician`
**Title:** "What electrical help do you need?"
**Subtitle:** "Select the type of electrical work you need"

#### Categories
- **Lighting** — New lights, repairs and upgrades
- **Sockets & Switches** — New sockets, switches and repairs
- **Consumer Unit** — Fuse box upgrades and repairs
- **Rewiring** — Full or partial rewiring
- **Testing & Certification** — EICR and safety certificates
- **Appliance Installation** — Cookers, showers, extractors
- **EV Charger** — Electric vehicle charger installation
- **Smart Home** — Smart switches, lighting and automation
- **Outdoor Electrical** — Garden lighting and external power
- **Emergency** (Urgent) — Power failures and dangerous faults

---

### 3. Painter

**File:** `painter.json`
**Key:** `painter`
**Title:** "What painting help do you need?"
**Subtitle:** "Select the type of painting work you need"

#### Categories
- **Interior Painting** — Walls, ceilings, rooms
- **Exterior Painting** — House fronts, windows, doors
- **Wallpapering** — Hanging and stripping wallpaper
- **Preparation Work** — Filling, sanding, priming
- **Specialist Finishes** — Murals, effects, restoration
- **Commercial** — Offices, shops, commercial spaces

---

### 4. Carpenter

**File:** `carpenter.json`
**Key:** `carpenter`
**Title:** "What carpentry help do you need?"
**Subtitle:** "Select the type of carpentry work you need"

#### Categories
- **Doors** — Internal, external, fitting, repairs
- **Wooden Windows** — Sash windows, frames, sills
- **Wooden Flooring** — Installation, repairs, sanding
- **Staircases** — New stairs, repairs, balustrades
- **Storage & Shelving** — Wardrobes, cupboards, shelves
- **Decking** — Timber decking installation
- **Fencing & Gates** — Wooden fencing and gates
- **Bespoke/Custom** — Furniture and custom woodwork

---

### 5. Handyman

**File:** `handyman.json`
**Key:** `handyman`
**Title:** "What handyman help do you need?"
**Subtitle:** "Select the type of job you need done"

#### Categories
- **Furniture Assembly** — Flat-pack, disassembly, repair
- **Wall Mounting** — TVs, mirrors, pictures, shelves
- **General Repairs** — Doors, windows, drawers, cupboards
- **Bathroom Jobs** — Small bathroom tasks
- **Kitchen Jobs** — Handles, shelving, appliances
- **Outdoor Jobs** — Fence repair, gutter cleaning
- **Odd Jobs** — Sealant, grouting, paint touch-ups

---

## Building & Construction

### 6. Roofer

**File:** `roofer.json`
**Key:** `roofer`
**Title:** "What roofing help do you need?"
**Subtitle:** "Select the type of roofing work you need"

#### Categories
- **Roof Repairs** — Leaks, damaged tiles and repairs
- **New Roof** — Complete roof installation
- **Flat Roofs** — Flat roof repairs and installations
- **Guttering & Drainage** — Gutter repairs and installation
- **Fascias & Soffits** — Board repairs and replacement
- **Chimneys** — Chimney repairs and maintenance
- **Skylights & Roof Windows** — Velux and skylight installation
- **Emergency** (Urgent) — Storm damage and major leaks

---

### 7. Builder

**File:** `builder.json`
**Key:** `builder`
**Title:** "What building work do you need?"
**Subtitle:** "Select the type of building project"

#### Categories
- **Extensions** — Single storey, double storey, rear, side
- **Loft Conversions** — All types of loft conversion
- **Garage Conversions** — Garage to living space
- **Structural Work** — Walls, RSJs, underpinning
- **Brickwork & Masonry** — Walls, repointing, repairs
- **Renovations** — House renovations and refurbishments
- **Outbuildings** — Garden rooms, sheds, annexes
- **Groundwork** — Foundations, drainage, excavation

---

### 8. Plasterer

**File:** `plasterer.json`
**Key:** `plasterer`
**Title:** "What plastering help do you need?"
**Subtitle:** "Select the type of plastering work"

#### Categories
- **Skimming** — Skim coat over existing surfaces
- **Plaster Repairs** — Patch repairs, cracks, holes
- **New Plastering** — Fresh plaster on new surfaces
- **Artex & Textured** — Removal and covering
- **Rendering** — External wall rendering
- **Coving & Cornices** — Decorative ceiling edges
- **Plasterboard** — Dry lining and boarding

---

### 9. Tiler

**File:** `tiler.json`
**Key:** `tiler`
**Title:** "What tiling help do you need?"
**Subtitle:** "Select the type of tiling work you need"

#### Categories
- **Bathroom Tiling** — Walls, floors, showers
- **Kitchen Tiling** — Floors, splashbacks, walls
- **Floor Tiling** — Hallway, conservatory, living
- **Wall Tiling** — Feature walls, fireplaces
- **Outdoor Tiling** — Patio, pool area, steps
- **Specialist Tiling** — Mosaic, large format, stone
- **Repairs & Maintenance** — Broken tiles, re-grouting
- **Tile Removal** — Strip existing tiles

---

### 10. Glazier

**File:** `glazier.json`
**Key:** `glazier`
**Title:** "What glazing help do you need?"
**Subtitle:** "Select the area that best describes your issue"

#### Categories
- **Window Replacement** — Single, multiple, sash, bay/bow, upgrade to double/triple
- **Door Installation** — Front door (composite/uPVC/timber/aluminium), back door, patio/sliding, French, bi-fold
- **Double / Triple Glazing** — New throughout, triple glazing, secondary glazing, misted units
- **Glass Repairs** — Cracked glass, broken glass, foggy panes, lock/handle/hinge repair
- **Conservatories** — New conservatory, roof replacement, repairs, orangery
- **Roof Windows / Skylights** — VELUX, flat roof lights, sun tunnels, replacements, leaks
- **Emergency Boarding Up** (Urgent) — Board up window/door, emergency glass, break-in damage
- **Other** — General advice, multiple jobs

---

### 11. Scaffolder

**File:** `scaffolder.json`
**Key:** `scaffolder`
**Title:** "What scaffolding do you need?"
**Subtitle:** "Select the area that best describes your requirement"

#### Categories
- **Domestic Scaffolding** — Front/rear of house, chimney/roof/gutter access (1–3 storey)
- **Commercial Scaffolding** — Commercial building, church/heritage, pavement scaffold, loading bay
- **Tower Scaffold Hire** — Hire (up to 4m / 4–8m / 8m+), erection, relocation
- **Scaffold Inspection** — Initial, weekly, post-weather, written report
- **Temporary Roof** — Install, extend, remove weather protection
- **Scaffold Dismantling** — Full, partial, emergency removal
- **Other** — General advice, multiple jobs

---

### 12. Welder

**File:** `welder.json`
**Key:** `welder`
**Title:** "What welding or metalwork do you need?"
**Subtitle:** "Select the area that best describes your requirement"

#### Categories
- **Gate Fabrication** — Single/double/sliding gates, gate repair (hinge/latch/post/weld), automation
- **Railings & Balustrades** — Staircase handrail, balcony, garden/boundary, Juliet balcony, repairs
- **Security Grilles** — Window grilles, door grilles, roller shutters, cage enclosures
- **Structural Steelwork** — RSJ/beam installation, steel columns, frames, mezzanine
- **Repairs & Modifications** — Weld repair, rust treatment, modifications, on-site welding
- **Decorative Metalwork** — Garden art, fire pits, metal furniture, house numbers/signs
- **Other** — General advice, multiple jobs

---

## Outdoor & Garden

### 13. Gardener

**File:** `gardener.json`
**Key:** `gardener`
**Title:** "What gardening help do you need?"
**Subtitle:** "Select the type of garden work you need"

#### Categories
- **Lawn Care** — Mowing, treatment, seeding, repair
- **Planting** — Flowers, shrubs, trees, containers
- **Hedges & Trees** — Trimming, pruning, removal
- **Garden Clearance** — Overgrown gardens, waste removal
- **Light Landscaping** — Borders, beds, basic paving
- **Fencing & Boundaries** — Garden fencing and repairs
- **Regular Maintenance** — Ongoing garden care

---

### 14. Landscaper

**File:** `landscaper.json`
**Key:** `landscaper`
**Title:** "What landscaping help do you need?"
**Subtitle:** "Select the type of landscaping work you need"

#### Categories
- **Garden Design** — Full design and consultancy
- **Paving & Patios** — Stone, block, slabs, edging
- **Decking** — Timber and composite decking
- **Garden Structures** — Pergolas, arbours, raised beds
- **Water Features** — Ponds, fountains, irrigation
- **Soft Landscaping** — Lawns, planting, borders
- **Garden Lighting** — Outdoor lighting design

---

### 15. Tree Surgeon

**File:** `tree_surgeon.json`
**Key:** `tree_surgeon`
**Title:** "What tree surgery help do you need?"
**Subtitle:** "Select the type of tree work you need"

#### Categories
- **Pruning & Trimming** — Crown reduction, thinning, lifting
- **Tree Removal** — Felling, section felling
- **Stump Work** — Grinding, removal, treatment
- **Hedge Work** — Trimming, reduction, removal
- **Tree Planting** — Planting and staking
- **Tree Health** — Inspection and treatment
- **Emergency** (Urgent) — Storm damage, fallen trees

---

## Heating & Gas

### 16. Central Heating

**File:** `central_heating.json`
**Key:** `central_heating`
**Title:** "What central heating help do you need?"
**Subtitle:** "Select the type of heating work you need"

#### Categories
- **New Installation** — Full systems, underfloor heating
- **Radiator Work** — Install, move, replace, repair
- **System Cleaning** — Powerflush, chemical flush
- **Controls & Thermostats** — Smart and standard controls
- **Repairs** — No heating, cold radiators, leaks
- **Service & Maintenance** — Annual service, gas safety
- **Renewable Heating** — Heat pumps, solar thermal
- **Emergency** (Urgent) — No heat, gas smell

---

### 17. Boiler Repair

**File:** `boiler_repair.json`
**Key:** `boiler_repair`
**Title:** "What boiler help do you need?"
**Subtitle:** "Select the type of boiler service you need"

#### Categories
- **Boiler Repair** — No heating, no hot water, leaks
- **Boiler Service** — Annual, landlord, warranty
- **Boiler Installation** — Combi, system, regular
- **Boiler Brands** — Worcester, Vaillant, Baxi, etc.
- **Controls & Thermostats** — Smart and standard
- **Hot Water Cylinder** — Install, replace, repair
- **System Maintenance** — Powerflush, filters
- **Emergency** (Urgent) — Gas smell, breakdown, CO alarm

---

### 18. Gas Engineer

**File:** `gas_engineer.json`
**Key:** `gas_engineer`
**Title:** "What gas work do you need?"
**Subtitle:** "Select the area that best describes your issue"

#### Categories
- **Gas Cooker Installation** — Install/disconnect cooker/hob, bayonet fitting, cooker repair
- **Gas Fire Servicing** — Annual service, install, repair (won't light/pilot/yellow flame/gas smell), removal
- **Gas Leak Repair** (Urgent) — Smell gas, gas alarm, leak at meter/appliance
- **Gas Safety Certificates (CP12)** — Landlord CP12, homeowner check, multiple appliance check
- **Gas Meter Relocation** — Move meter internal/external, install meter box
- **New Gas Supply** — New gas pipe run, gas to extension/outbuilding, pipe repair
- **Other** — General advice, multiple jobs

---

### 19. HVAC Technician

**File:** `hvac_technician.json`
**Key:** `hvac_technician`
**Title:** "What HVAC help do you need?"
**Subtitle:** "Select the area that best describes your issue"

#### Categories
- **Air Conditioning Installation** — Split system (single/multi-room), portable, ducted, ceiling cassette, commercial
- **Heat Pump Installation** — Air source, ground source, hybrid system, hot water heat pump
- **AC Servicing & Repair** — Annual service, not cooling (warm air/weak/ice), noisy, leaking, bad smell
- **Refrigeration** — Walk-in fridge/freezer, commercial refrigeration, cold room repair, refrigerant recharge
- **Ventilation Systems** — MVHR, extract fan, ducting, ventilation survey
- **F-Gas Leak Check** — Annual leak check, suspected leak, leak repair and recharge
- **Other** — General advice, multiple jobs

---

## Kitchen & Bathroom

### 20. Kitchen Fitter

**File:** `kitchen_fitter.json`
**Key:** `kitchen_fitter`
**Title:** "What kitchen work do you need?"
**Subtitle:** "Select the area that best describes your requirement"

#### Categories
- **Full Kitchen Installation** — New kitchen (supply & fit / fit only / IKEA / Howdens), refit, kitchen in extension
- **Worktop Fitting** — Laminate, solid wood, quartz/granite, joins/cut-outs, replacement
- **Kitchen Unit Replacement** — Replace doors, replace/add units, drawer/hinge repair
- **Appliance Installation** — Built-in oven, hob, dishwasher, fridge/freezer, extractor, washing machine
- **Kitchen Design Consultation** — Measure up and quote, design advice, feasibility check
- **Kitchen Demolition / Strip Out** — Full/partial strip out, waste disposal, wall preparation
- **Other** — General advice, multiple jobs

---

## Security

### 21. Locksmith

**File:** `locksmith.json`
**Key:** `locksmith`
**Title:** "What locksmith help do you need?"
**Subtitle:** "Select the type of lock service you need"

#### Categories
- **Locked Out** (Urgent) — Emergency access
- **Lock Changes** — Replace existing locks
- **Lock Repairs** — Fix faulty or damaged locks
- **New Lock Installation** — Fit additional locks
- **Security Upgrades** — High security, anti-snap
- **Smart Locks** — Keyless and app-controlled
- **Commercial Locks** — Business and access control
- **Emergency** (Urgent) — Burglary, urgent access

---

## Automotive

### 22. Mechanic

**File:** `mechanic.json`
**Key:** `mechanic`
**Title:** "What vehicle help do you need?"
**Subtitle:** "Select the type of vehicle service you need"

#### Categories
- **Vehicle Service** — Full, interim, major, oil change
- **MOT** — Test, repairs, pre-MOT check
- **Brakes** — Pads, discs, fluid, calipers
- **Tyres & Wheels** — New tyres, punctures, alignment
- **Engine** — Diagnostics, timing belt, clutch, gearbox
- **Electrical** — Battery, starter, alternator, lights
- **Exhaust & Emissions** — Exhaust, catalytic, DPF
- **Suspension & Steering** — Shocks, springs, steering
- **Cooling System** — Radiator, water pump, thermostat
- **Emergency** (Urgent) — Breakdown, won't start

---

## Cleaning

### 23. Cleaner

**File:** `cleaner.json`
**Key:** `cleaner`
**Title:** "What cleaning help do you need?"
**Subtitle:** "Select the type of cleaning service you need"

#### Categories
- **Domestic Cleaning** — Regular, deep clean, spring clean, one-off
- **End of Tenancy** — Full property, inventory standard, move-in/out, deposit guarantee
- **Specialist Cleaning** — Carpet, upholstery, oven, windows, mattress
- **Kitchen Deep Clean** — Full kitchen, oven/hob, fridge/freezer, extractor, cupboards, appliances
- **Bathroom Deep Clean** — Full bathroom, limescale, mould, grout, shower
- **Outdoor Cleaning** — Pressure washing (driveway/patio/decking), gutters, conservatory, fascia, windows
- **After Event/Building** — Post party, post building/renovation, after decoration, new build sparkle
- **Commercial** — Office, retail/shop, communal areas, Airbnb/holiday let, restaurant/cafe
- **Other** — Quote, regular cleaner, unlisted

---

## Personal Care

### 24. Hairdresser

**File:** `hairdresser.json`
**Key:** `hairdresser`
**Title:** "What hairdressing service do you need?"
**Subtitle:** "Select the type of hair service you're looking for"

#### Categories
- **Cutting & Styling** — Ladies' cut (trim/restyle/layers/fringe/dry cut), men's cut (scissor/clipper/fade/beard), children's cut, blow-dry/styling (standard/bouncy/up-do/curls)
- **Colouring** — Full head colour (same shade/new/grey coverage/fashion), root touch-up, highlights/lowlights (half/full/T-section), balayage/ombré (babylights/colour melt), toner/gloss, colour correction (strip/banding/tone fix/go lighter)
- **Treatments** — Deep conditioning (moisture/protein/Olaplex/hot oil), keratin/smoothing (Brazilian/nanoplastia), scalp treatment (dry/oily/detox), hair loss consultation
- **Hair Extensions** — New fitting (tape-in/micro-ring/weave/fusion/clip-in), maintenance (move up/replace tapes/bonds), removal
- **Perming & Texture** — Perm (full/partial/beach wave/spiral), relaxer (full/touch-up), Japanese straightening
- **Bridal & Occasions** — Bridal hair (trial/wedding day/package), bridesmaids, prom, special occasion (up-do/Hollywood waves/braids/blow-dry)
- **Afro & Textured Hair** — Braiding (box braids/cornrows/twists/faux locs/crochet), natural hair care (wash & go/twist out/silk press/trim), loc maintenance (retwist/interlock/repair/starter), wig/weave install (lace front/full weave/closure/customisation)
- **Other** — Consultation, quote, unlisted

---

## Other

### 25. Other Services

**File:** `other.json`
**Key:** `other`
**Title:** "Tell us what you need help with"
**Subtitle:** "Describe your job or select an option below"

#### Categories
- **Describe Your Job** — General help requests
- **I'm Not Sure** — Help finding the right tradesperson
- **Get Quotes** — Compare quotes from tradespeople
- **Emergency Help** (Urgent) — Urgent help needed

---

## Service Categories

| Order | Category | Trades |
|-------|----------|--------|
| 1 | Home Services | Plumber, Electrician, Painter, Carpenter, Handyman |
| 2 | Building & Construction | Roofer, Builder, Plasterer, Tiler, Glazier, Scaffolder, Welder |
| 3 | Outdoor & Garden | Gardener, Landscaper, Tree Surgeon |
| 4 | Heating & Gas | Central Heating, Boiler Repair, Gas Engineer, HVAC Technician |
| 5 | Kitchen & Bathroom | Kitchen Fitter |
| 6 | Security | Locksmith |
| 7 | Automotive | Mechanic |
| 8 | Cleaning | Cleaner |
| 9 | Personal Care | Hairdresser |
| 10 | Other | Other Services |

---

## Icon Reference

All icons use LucideIcons. Common icons used:

| Icon | Usage |
|------|-------|
| `wrench` | Repairs, general services |
| `siren` | Emergency/urgent categories |
| `messageSquare` | Other/description required |
| `flame` | Heating/boiler/gas services |
| `droplet` | Water/plumbing related |
| `zap` | Electrical services |
| `house` / `home` | Property/house related |
| `car` | Vehicle/automotive |
| `sparkles` | Cleaning / specialist services |
| `scissors` | Hairdressing services |
| `doorOpen` | Doors, glazing |
| `airVent` | HVAC/ventilation |
| `construction` | Scaffolding |
| `shield` | Security, welding |
| `chefHat` | Kitchen services |
| `palette` | Colour/colouring services |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-12-31 | Initial creation with 21 services |
| 2.0 | 2025-12-31 | Enhanced with subtitles, descriptions, and nested options |
| 3.0 | 2026-02-25 | Added Glazier, Gas Engineer, HVAC Technician, Scaffolder, Welder, Kitchen Fitter, Hairdresser. Reorganised by category. Total: 25 services |

---
