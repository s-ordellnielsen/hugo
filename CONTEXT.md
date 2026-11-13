# Hugo

Hugo helps a Jehovah's Witness publisher log their ministry time, send the monthly report to their group overseer and follow their goal for the theocratic year.

## Time

**Entry**:
One piece of logged ministry time: a date, a duration, a category and optionally a number of Bible studies.
_Avoid_: Record, log, session

**Category**:
What an entry's time counts as, such as Field Service or Bethel. Every category is either a main category or a separate category.
_Avoid_: Tracker, type

**Main category**:
A category whose time is reported together on the Field Service line.
_Avoid_: Primary category

**Separate category**:
A category whose time is reported on its own line, apart from Field Service, such as Bethel or LDC.
_Avoid_: Other, secondary category

**Default category**:
The main category that new entries use unless the user picks another. A new install starts with one, named Field Service.

**Category snapshot**:
The name, icon and kind of an entry's category, copied onto the entry so the entry keeps its category if the category is renamed or deleted.

**Category color**:
The color a category is drawn in: Automatic (the app's accent color) or a hue and a tone the user picked. The tone gives a deeper color in light mode and a lighter one in dark mode, so the same choice stays visible on both. A category color is only a visual aid; names and order always tell categories apart.
_Avoid_: Tint, theme color

**Untracked entry**:
An entry that has neither a category nor a category snapshot. Its time counts as main time everywhere: on the Field Service line, in the month's main total and toward the yearly goal.

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
One line of a report: Field Service, which holds all main time, or one separate category. Each line is rounded on its own.

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
The group overseer who receives the publisher's reports.

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

**Credited time**:
The part of a month's time that counts toward the yearly goal: all main time, plus separate time until the month reaches its monthly goal plus the separate allowance. The app shows it as "Counted toward goal".
_Avoid_: Counted time

**Separate allowance**:
The hours of separate-category time that may count beyond the monthly goal in one month.

**Expected time**:
The credited time the user should have by now to reach the yearly goal at an even pace.

**Current month calculation**:
How expected time is worked out for the current month: in proportion to the inclusive day fraction, counting only completed months, or counting the whole current month. Settings calls this "Current Month Calculation" / "Beregning af nuværende måned". It changes expected time, not credited or logged time. Persisted code names remain `YearlyGoalPacing`.

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
The remaining yearly goal divided over the months left in the theocratic year, including the current month, rounded up to whole hours and based on credited time before the current month. The Settings label is "Adjusted to yearly goal" / "Tilpasset årsmålet". The Settings explanation names the remaining goal and month count. The persisted case remains `yearlyGoalShare`.

**Buffer**:
The nonnegative hours added to the base monthly target. Without a publisher-status goal, the same preference sets the whole personal monthly target. Settings calls it "Buffer" / "Buffer". Historical storage and API names remain `plannerExtraHours` / `extraHours`. The Planner bar draws the base as a solid fill and Buffer as a separate faded extension.

**Plan pace**:
How the current month's logged time compares with the time planned up to now. Today's plan counts only as far as it has been logged.

**Covered time**:
The part of a category's planned time on a day that logged time accounts for: first time in that category, then other time of the same kind (main or separate). Hugo matches per category, not per plan, and ignores start times, because an entry does not record whether its time was picked or guessed. The Planner draws each category's plans on a day as one bar, filled as far as the covered time goes. Time beyond the plans stays on that bar.

**Unplanned time**:
Logged time in a category that has no plan on that day and that no plan of the same kind took. It gets its own bar.

**Logging a plan**:
Opening Add Entry filled from a category's plans on a day: the category, the start time of the first plan not covered yet, and the planned time not covered yet. The user still saves the entry, and the plans stay.

## Sync

**Sync duplicate**:
Two copies of the same row that two devices each created before they synced. Hugo merges them and keeps one, the survivor.
_Avoid_: Conflict

**Canonical report**:
The one submitted report Hugo uses for a month when sync duplicates or placeholder reports leave more than one.

## Flagged ambiguities

- "Actual" has meant logged time in some places and year total in others. Say logged time, reported hours, year total or credited time instead.
- "Field Service" names both the default category and the reporting line that holds all main time. Say "the Field Service line" for the line.
