window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'IDENTITY',
  nav: 'Onboarding',
  kicker: 'profile completion + postcode lookup',
  title: 'Onboarding — from a bare auth user to a usable profile',
  summary: `
    A verified Firebase Auth user has no name, no phone and no address — nothing the app can
    put on a quote. Onboarding is two or three short steps that fill exactly the fields the
    gate predicate checks, and no more. The middle step (company details) is optional and is
    skipped entirely by a sole trader.`,
  blocks: [
    {
      title: 'The step flow',
      html: `
<p>
  Each step writes to <code>users/{uid}</code> through <code>AuthBloc</code>, waits a beat for
  the RTDB stream to flush, then pushes the next route. That deliberate 500–600 ms pause is
  there because the next step hydrates its form from
  <code>AuthBloc.state.userDetails</code> — navigating instantly would show it stale data.
</p>`,
      caption: 'Onboarding route flow',
      mermaid: `graph LR
  GATE["handleAuthentication<br/>_needsOnboarding = true"] --> P["/onboarding/personal<br/>PersonalDetailsStep"]
  P --> Q{"user ticked<br/>I have a company?"}
  Q -->|"yes"| C["/onboarding/company<br/>CompanyDetailsStep"]
  Q -->|"no"| A["/onboarding/address<br/>AddressStep"]
  C --> A
  A --> PAY["/choosePlan<br/>pushNamedAndRemoveUntil"]
  PAY --> HOME["/tradesmanHome<br/>once entitled"]`,
    },
    {
      title: 'Pipeline — step 1, personal details',
      html: `
<p>
  Continue is enabled on <strong>first name ≥ 2 chars and phone ≥ 7 chars</strong>. Last name
  is not required, and the code comment explains why: Apple and Google frequently return no
  surname, and some people simply do not have one — requiring it permanently disabled the
  button for those users.
</p>
<p>
  The write bootstraps <code>email</code>, <code>id</code> and
  <code>accountType: tradesman</code> alongside the typed fields, because a fresh signup may
  have no record at all. <code>verificationStatus</code> is <em>not</em> written — the RTDB
  rules forbid client writes to it.
</p>`,
      caption: 'Personal details → RTDB → stream → next step',
      mermaid: `sequenceDiagram
  autonumber
  participant U as User
  participant S as PersonalDetailsStep
  participant B as AuthBloc
  participant R as AuthRepository
  participant DB as RTDB users/{uid}
  participant N as Navigator

  Note over S: _hydrate() pre-fills from<br/>AuthBloc userDetails, falling back to<br/>Firebase displayName (Apple / Google)
  U->>S: first name, last name (optional), phone
  S->>S: _canContinue — first >= 2, phone >= 7
  U->>S: tap Continue
  S->>B: UpdateUserDetailsRequested(updates)
  B->>R: updateUserDetails(map)
  R->>DB: update firstName, lastName, phoneNumber,<br/>accountType, email, id
  DB-->>B: streamUserDetails() tick
  B-->>S: state.userDetails refreshed
  S->>S: await 500ms so the tick lands
  S->>N: push /onboarding/company or /onboarding/address`,
    },
    {
      title: 'Pipeline — step 2, company details (optional)',
      html: `
<p>
  Only reached when the user says they trade as a company. It captures company name, a
  business phone, an optional website and VAT registration. VAT matters downstream: it is what
  a quote or invoice needs in order to show a VAT number in its header.
</p>`,
      caption: 'Company details',
      mermaid: `graph LR
  A["CompanyDetailsStep<br/>name, phone, website, VAT toggle"] --> B["AuthBloc<br/>SaveBusinessProfileRequested"]
  B --> C["AuthRepository<br/>updateUserDetails"]
  C --> D["RTDB users/{uid}/companyDetails<br/>companyName, companyLandline,<br/>website, vatRegistered, vatNumber"]
  D --> E["stream tick → AuthBloc state"]
  E --> F["await 600ms"]
  F --> G["push /onboarding/address"]`,
    },
    {
      title: 'Pipeline — step 3, address via Ordnance Survey',
      html: `
<p>
  The final step is the only one that calls a non-Firebase API. The user types a UK postcode;
  <code>AddressGeocoder.forPostcode()</code> hits the
  <strong>Ordnance Survey Places API</strong> and returns every delivery point for that
  postcode. Picking one fills line 1, city, county and — importantly — latitude and longitude,
  which is what later powers the static-map thumbnails and the "Get directions" action.
</p>
<p>
  This is the step that flips <code>_needsOnboarding</code> to false, because postcode is the
  canonical probe for "this profile has an address".
</p>`,
      caption: 'Postcode → OS Places API → address + coordinates → RTDB',
      mermaid: `sequenceDiagram
  autonumber
  participant U as User
  participant S as AddressStep
  participant P as PostcodeSearchButton
  participant G as AddressGeocoder
  participant OS as api.os.uk /search/places/v1/postcode
  participant B as AuthBloc
  participant DB as RTDB users/{uid}
  participant N as Navigator

  U->>S: type postcode, tap search
  S->>P: push AddressSearch
  P->>G: forPostcode(raw)
  G->>OS: GET ?postcode=…&key=OS_PLACES_API_KEY
  alt no results / API error
    OS-->>G: empty or non-200
    G-->>P: empty list
    P-->>U: "no addresses found" — manual entry still allowed
  else results
    OS-->>G: DPA records
    G-->>P: List of AddressResult<br/>(line1, city, county, postcode, lat, lng)
    U->>P: pick one
    P-->>S: AddressResult
  end
  S->>S: build AddressModel + LocationModel
  U->>S: tap Finish
  S->>B: UpdateUserDetailsRequested(address, location,<br/>lastAddressUpdatedAt)
  B->>DB: update
  DB-->>B: stream tick
  S->>S: await 600ms
  S->>N: pushNamedAndRemoveUntil(/choosePlan)`,
    },
    {
      title: 'What the coordinates are used for later',
      html: `
<p>
  Latitude / longitude captured here (and on every customer record) are reused in three
  places, which is why the geocoding step earns its keep:
</p>
<table>
  <tr><th>Consumer</th><th>Use</th></tr>
  <tr><td>Settings → Address</td><td>Map preview of the saved address</td></tr>
  <tr><td>Customer edit, New job, Tradesman home</td><td>"Get directions" — on iOS a Cupertino chooser between Apple and Google Maps; on Android it short-circuits straight to Google Maps, because Apple Maps does not exist there</td></tr>
  <tr><td>Static map thumbnails</td><td>Google Maps Static API renders a URL straight into an <code>Image</code>; the interactive SDK was removed</td></tr>
</table>`,
    },
    {
      title: 'A note on the legacy registration screens',
      html: `
<p>
  <code>lib/screens/authentication/tradesman/</code> and <code>…/business/</code> still hold a
  much longer registration journey — role select, national insurance number, identity
  documents, selfie upload, trade qualifications, service selection, a verification-waiting
  screen and a rejection screen. Those screens are on disk and their routes largely still
  resolve, but the live flow no longer visits them: the current gate goes straight from email
  verification to the three onboarding steps.
</p>
<p>
  The residue is visible elsewhere: <code>UserDetailsModel</code> still carries
  <code>verificationStatus</code>, <code>documentUrls</code>, <code>selfieUrl</code>,
  <code>nationalInsuranceNumber</code> and <code>trade</code>, and the Cloud Function trigger
  <code>onVerificationStatusChanged</code> still watches for that field flipping to
  <code>verified</code> so it can send a welcome email.
</p>`,
      caption: 'Live path vs. retained-but-unreached path',
      mermaid: `graph TB
  subgraph LIVE["Live flow"]
    A["/emailVerify"] --> B["/onboarding/personal"]
    B --> C["/onboarding/company (optional)"]
    C --> D["/onboarding/address"]
    D --> E["/choosePlan"]
    E --> F["/tradesmanHome"]
  end

  subgraph LEGACY["Retained on disk, not reached by the gate"]
    G["/createAccountCategory<br/>SelectRoleScreen"]
    H["tradesman: user details, address,<br/>company, NI number, identity docs,<br/>selfie, trade qualifications, services"]
    I["/tradesmanVerifyWaiting"]
    J["/tradesmanRejected"]
    K["business: user details, address,<br/>service selection, /teamOnboarding"]
    G --> H --> I --> J
    G --> K
  end

  L["onVerificationStatusChanged trigger<br/>still armed on users/{uid}/verificationStatus"] -.-> I`,
    },
  ],
});
