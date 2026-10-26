# Security

Dayline stores personal tasks on the local Mac. Please keep vulnerability reports free of that data.

## Report a problem

Use a private GitHub security advisory on [dushiye/Dayline](https://github.com/dushiye/Dayline) if the repository allows it. Otherwise email the address on the maintainer’s GitHub profile. Do not file a public issue for a vulnerability that exposes local data.

Include the version, the macOS version, and enough detail to reproduce the issue on synthetic data.

## In scope

- The Mac app reading or writing outside its data folder without the user choosing a file.
- Backup or restore corrupting a library, or replacing it without confirmation.
- Install scripts deleting `~/Library/Application Support/Dayline` or an existing `Dayline.app`.
- Secrets committed to the repository.

## Out of scope

- An ad-hoc signed build, when the user compiled it on their own Mac. That is the expected install path until notarization exists.
- A person with access to your unlocked Mac reading the local database.
- Sample content, which is optional and can be deleted.

There is no bug bounty.
