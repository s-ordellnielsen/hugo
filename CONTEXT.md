# Hugo

Hugo helps a Jehovah's Witness publisher log their ministry time, send the monthly report to their group overseer and follow their goal for the theocratic year.

## Time

**Entry**:
One piece of logged ministry time: a date, a duration, a category and optionally a number of Bible studies.
_Avoid_: Record, log, session

**Category**:
What an entry's time counts as, such as Field Service or Bethel. Every category has a kind: it is either a Field Service category or a Credit category.
_Avoid_: Tracker, type

**Category kind**:
Whether a category is a Field Service category or a Credit category. The user picks it on two cards when adding or editing a category; the screens label the choice "Category Type" / "Type". Stored as `TrackerType`, whose cases stay `main` (Field Service) and `separate` (Credit).
_Avoid_: Output type, main, separate (in text users read)

**Field Service category**:
A category for time spent preaching and teaching. Its time is reported together on the Field Service line, counts in full toward the yearly goal, and its entries can have Bible studies. Danish: "Forkyndelse". Code: `TrackerType.main`.
_Avoid_: Main category, primary category

**Credit category**:
A category for hours a publisher may report as credit, such as Bethel or LDC. Each Credit category is reported on its own line, and its time counts toward the yearly goal only up to the credit allowance. New entries in it get no Bible studies; an entry that already has some keeps them. Danish: "Godtgørelse". Code: `TrackerType.separate`.
_Avoid_: Separate category, other, secondary category

**Credit**:
Hours reported for approved work other than field service: the time in Credit categories and school credit. Each is reported on a line of its own. Credit-category time counts toward the yearly goal only up to the credit allowance; school credit counts in full.

**Default category**:
The Field Service category that new entries use unless the user picks another. A new install starts with one, named Field Service ("Forkyndelse").

**Category snapshot**:
The name, icon and kind of an entry's category, copied onto the entry so the entry keeps its category if the category is renamed or deleted.

**Category color**:
The color a category is drawn in: Automatic (the app's accent color) or a hue and a tone the user picked. The tone gives a deeper color in light mode and a lighter one in dark mode, so the same choice stays visible on both. A category color is only a visual aid; names and order always tell categories apart.
_Avoid_: Tint, theme color

**Untracked entry**:
An entry that has neither a category nor a category snapshot. Its time counts as Field Service time everywhere: on the Field Service line, in the month's Field Service total and toward the yearly goal.

**Logged time**:
The sum of entry durations, before any rounding.
_Avoid_: Actual time, raw time

**Month**:
One calendar month. A report always covers exactly one month.

**Theocratic year**:
The year from September 1 to August 31, written as both calendar years, for example 2026/2027.
_Avoid_: Service year, school year

## Reports

**Report**:
What the publisher sends the overseer for one month: whole hours for each reporting line and the number of Bible studies.

**Submitted report**:
Hugo's saved copy of a report that was sent, including when it was sent and which entries it covered.
_Avoid_: Monthly report

**Service month**:
One month together with its entries and its canonical report. It tells whether the month is submitted, whether it has an unreported change and what it adds to the year total.

**Placeholder report**:
A saved report for a month that was never actually sent, left behind when older data was upgraded. It counts as not submitted.
_Avoid_: Sentinel, backfill

**Reporting line**:
One line of a report: the Field Service line, which holds all Field Service time, or one Credit category. Each line is rounded on its own. School credit is sent on lines of its own but is not a reporting line.

**Remainder**:
The minutes on a reporting line beyond its whole hours.

**Rounding rule**:
What happens to a reporting line's remainder: round up, round down or transfer. The user picks one per line when submitting.

**Transfer**:
The rounding rule that moves a reporting line's remainder into the next month.
_Avoid_: Carry over (as the rule's name)

**Carried-in entry**:
An entry Hugo creates on the 1st of the next month to hold minutes that were transferred.
_Avoid_: Generated entry, carry entry

**Reported hours**:
The whole hours on a submitted report's lines.
_Avoid_: Submitted time

**Unreported change**:
A difference between a submitted month and its entries now: an entry added after the report was sent, or totals that no longer match the report. A month with an unreported change should be submitted again.

**Due month**:
The month whose report the Overview currently reminds the user to send.

**Overseer**:
The group overseer who receives the publisher's reports. The user chooses them from Contacts or types their name and phone number in Settings. Hugo saves the name and number, never a link to the contact.

**Greeting template**:
The user's own opening text that Hugo puts at the top of each report message.

## Goals

**Publisher status**:
The user's role, which sets their goal: publisher, auxiliary pioneer or regular pioneer.

**Monthly goal**:
The hours the publisher status expects in one month. A yearly goal is split evenly into twelve monthly goals.

**Yearly goal**:
The hours the publisher status expects in one theocratic year. Only statuses with a yearly goal get yearly goal progress.

**Year total**:
For one theocratic year: the reported hours of every submitted month plus the logged time of every month not yet submitted.
_Avoid_: Actual total

**Counted time**:
The part of a month's time that counts toward the yearly goal: all Field Service time and school credit, plus Credit-category time until the month reaches its monthly goal plus the credit allowance. The app shows it as "Counted toward goal" / "Tæller med mod målet". Code names remain `creditedSeconds`.
_Avoid_: Credited time (it sounds like time in Credit categories)

**Credit allowance**:
The hours of Credit-category time that may count beyond the monthly goal in one month: 5 for a regular pioneer. Code names remain `separateAllowanceHours` and `separateAllowanceSeconds`.
_Avoid_: Separate allowance

**School**:
A school whose attendance gives a fixed credit of hours toward the yearly goal, such as Pioneer Service School (30 hours, regular pioneers). Each school sets its quota and which publisher statuses may use it.

**School credit**:
Hours from a school, recorded for one month. It counts in full toward the yearly goal and the year total, like Field Service time, never goes through rounding, and is reported on its own line. It is credit, but not a Credit category. A school that spans two months is entered as one school credit per month.
_Avoid_: PSS hours, credit hours

**Expected time**:
The counted time the user should have by now to reach the yearly goal at an even pace: the monthly goal for each month of the theocratic year that is over, plus the current month's goal spread across the month. The current month adds its monthly goal times today's day number divided by the number of days in the month, so today counts as a whole day. On November 15 a regular pioneer (50 hours a month) expects 2 x 50 + 50 x 15/30 = 125 hours. For a past year it is the whole yearly goal; before the year starts there is none. The Year tab's goal bar marks it as "Target today" / "Mål i dag", on a scale that ends at the monthly goal times the months so far. With the Year switch on, each month's goal in this sum, and in the scale, is the monthly goal plus Buffer (current theocratic year only).

## Planning

**Planner**:
The tab where the user plans each month on a calendar and compares the plan with the time they log.

**Plan**:
Time the user intends to spend in service on one day: a duration, a category and optionally a start time. A plan never counts as logged time; logging stays a separate step.
_Avoid_: Planned entry, schedule, appointment

**Still planned**:
Planned time on today and later days that logged time has not yet covered. For each day and each kind of time, the planned time minus the logged time, never below zero.

**Projected time**:
A month's logged time plus its still-planned time. The Planner shows it as "Planned".
_Avoid_: Expected time (that is yearly-goal pacing)

**Monthly target**:
The hours the Planner aims at for one month: the monthly goal, or an adjusted yearly-goal base, plus Buffer. Without a publisher-status goal, the selected duration is the personal monthly target.
_Avoid_: Goal (the goal comes from the publisher status)

**Adjusted target**:
The remaining yearly goal divided over the months left in the theocratic year, including the current month, rounded up to whole hours and based on counted time before the current month. The Settings label is "Adjusted to yearly goal" / "Tilpasset årsmålet". The Settings explanation is one short sentence. The target preview shows the adjustment on its own line under the base target as a signed change, for example "Adjusted: +3 hours" / "Tilpasset: +3 timer", only while this option is chosen. The base target line always shows the monthly goal. The persisted case remains `yearlyGoalShare`.

**Buffer**:
The nonnegative hours added to the base monthly target. Without a publisher-status goal, the same preference sets the whole personal monthly target. Settings calls it "Buffer" / "Buffer". Historical storage and API names remain `plannerExtraHours` / `extraHours`. The Planner bar draws the base as a solid fill and Buffer as a separate faded extension. The Planner always counts it. Overview and the Year tab each count it only when the user turns on their own switch (`bufferInOverview` and `bufferInYear`, both off by default and synced). The switches live on a page titled "Count Buffer in" / "Medregn buffer i", opened from the "Counts in" / "Tæller i" row under the Buffer stepper, which shows only while the Buffer is above 0 hours. The Year tab adds it only in the current theocratic year, and never adds the adjusted target.

**Plan pace**:
How the current month's logged time compares with the time planned up to now. Today's plan counts only as far as it has been logged.

**Covered time**:
The part of a category's planned time on a day that time logged in that same category accounts for. Hugo matches per category, not per plan, and ignores start times, because an entry does not record whether its time was picked or guessed. Time in one category never covers another category's plans, even of the same kind (Field Service or Credit). The one exception is an untracked entry, which counts as Field Service time and covers a Field Service plan once every plan has taken its own category's time. The Planner draws each category's plans on a day as one bar, filled as far as the covered time goes. Time beyond the plans stays on that bar. The day's still-planned time is the sum of what its bars have left, so the Planner header agrees with the bars.

**Unplanned time**:
Logged time in a category that has no plan on that day. It gets its own bar.

**Logging a plan**:
Opening Add Entry filled from a category's plans on a day: the category, the start time of the first plan not covered yet, and the planned time not covered yet. The user still saves the entry, and the plans stay.

## Sync

**Sync duplicate**:
Two copies of the same row that two devices each created before they synced. Hugo merges them and keeps one, the survivor.
_Avoid_: Conflict

**Canonical report**:
The one submitted report Hugo uses for a month when sync duplicates or placeholder reports leave more than one.

**Synced setting**:
A setting that stays the same on all of the user's devices through iCloud key-value storage, such as the publisher status, the group overseer, the Planner target or the Buffer switches. The onboarding flags and the Overview list style are not synced settings.

## Flagged ambiguities

- "Actual" has meant logged time in some places and year total in others. Say logged time, reported hours, year total or counted time instead.
- "Field Service" names a category kind, the default category and the reporting line that holds all Field Service time. Say "a Field Service category" for any category of that kind, "the default category" for the one a new install creates, and "the Field Service line" for the line. In Danish the kind, the default category and the app's line label are all "Forkyndelse", but the report message calls the line "Timer", the word on the congregation's report form.
- "Credit" names a category kind, school credit and both together. Say "Credit category" for the kind, "school credit" for school hours, and "credit" only for both together. Never say "credited time"; say "counted time".
