//
//  ServiceYearMonthRow.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 20/08/2026.
//

import SwiftUI
import SwiftData

struct ServiceYearMonthRow: View {
	let month: TheocraticYearMonth
	
	@State private var isPresentingDetails = false
	@State private var isPresentingAddEntry = false
	@State private var isPresentingSubmitSheet = false
	
	private var summary: MonthlyReportSummary? {
		month.summary
	}
	
	private var totalSeconds: TimeInterval {
		summary?.totalSeconds ?? 0
	}
	
    var body: some View {
		VStack {
			header
			
			if month.isSubmitted, let submittedAt = month.submittedReport?.submittedAt {
				submissionStatus(submittedAt)
			}
			
			if let summary {
				activityBreakdown(summary)
			}
		}
		.padding(HugoLayout.Spacing.card)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color(.secondarySystemGroupedBackground))
		.clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
		.sheet(isPresented: $isPresentingDetails) {
			NavigationStack {
				MonthlyReportDetailView(month: month)
			}
		}
		.sheet(isPresented: $isPresentingAddEntry) {
			AddEntryView(seededDate: month.id.date())
		}
		.sheet(isPresented: $isPresentingSubmitSheet) {
			NavigationStack {
				SubmitReportView(month: month.id)
			}
		}
    }
}

private extension ServiceYearMonthRow {
	var header: some View {
		HStack {
			VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
				monthTitle
				duration
			}
			
			Spacer(minLength: HugoLayout.Spacing.regular)
			
			moreMenu
		}
	}
	
	var monthTitle: some View {
		Text(month.displayName)
			.font(.caption)
			.textCase(.uppercase)
			.tracking(HugoLayout.Typography.eyebrowTracking)
			.fontWeight(.semibold)
			.foregroundStyle(month.isFuture ? .tertiary : .secondary)
	}
	
	private var duration: some View {
		HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
			Text(displayedHours, format: .number)
				.font(.system(.title, design: .serif, weight: .bold))
				.foregroundStyle(summary == nil ? .tertiary : .primary)
			Text(hourLabel)
				.font(.system(.title3, design: .serif, weight: .semibold))
				.foregroundStyle(summary == nil ? .tertiary : .secondary)
		}
	}
	
	private var displayedHours: Int {
		if month.isSubmitted {
			return month.submittedReport?.submittedHours ?? 0
		}
		
		return Int((summary?.totalSeconds ?? 0) / 3_600)
	}
	
	private var hourLabel: LocalizedStringKey {
		displayedHours == 1
		? "service_year.month.hour"
		: "service_year.month.hours"
	}
}

private extension ServiceYearMonthRow {
	var moreMenu: some View {
		Menu {
			if !month.isFuture {
				Section {
					Button(
						"report.submit.button",
						systemImage: "doc.badge.arrow.up"
					) {
						isPresentingSubmitSheet = true
					}
				}
			}
			
			Section {
				if !month.isFuture {
					Button(
						"entry.add.label",
						systemImage: "plus"
					) {
						isPresentingAddEntry = true
					}
				}
				
				if summary != nil {
					Button(
						"report.row.menu.details",
						systemImage: "doc.text.magnifyingglass"
					) {
						isPresentingDetails = true
					}
				}
			}
		} label: {
			Label("common.more", systemImage: "ellipsis.circle.fill")
				.foregroundStyle(.secondary)
				.labelStyle(.iconOnly)
				.font(.title2)
				.frame(
					minWidth: HugoLayout.Size.minimumHitTarget,
					minHeight: HugoLayout.Size.minimumHitTarget
				)
				.contentShape(Rectangle())
				.symbolRenderingMode(.hierarchical)
		}
		.contentShape(.hoverEffect, Circle())
		.hoverEffect(.highlight)
		.padding(.trailing, -HugoLayout.Spacing.regular)
	}
}

private extension ServiceYearMonthRow {
	private static let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .none
		return formatter
	}()
	
	@ViewBuilder
	func submissionStatus(_ submittedAt: Date) -> some View {
			VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
				Label(
					"report.status.submitted.\(Self.dateFormatter.string(from: submittedAt))",
					systemImage: "checkmark.circle.fill"
				)
				.foregroundStyle(.hugoAccent)
				
				if month.hasUnreportedEntries {
					Label(
						"report.status.unreported-entries",
						systemImage: "exclamationmark.triangle.fill"
					)
					.foregroundStyle(.secondary)
				}
			}
			.font(.caption)
			.padding(.top, HugoLayout.Spacing.compact)
	}
}

private extension ServiceYearMonthRow {
	@ViewBuilder
	func activityBreakdown(_ summary: MonthlyReportSummary) -> some View {
		Divider()
		
		VStack(spacing: HugoLayout.Spacing.regular) {
			ForEach(summary.categories) { category in
				categoryRow(category)
			}
			
			Divider()
				.padding(.vertical, HugoLayout.Spacing.compact)
			
			bibleStudiesRow(summary.totalBibleStudies)
		}
		.padding(.top, HugoLayout.Spacing.regular)
		.labelReservedIconWidth(HugoLayout.Size.labelReservedIconWidth)
	}
	
	func categoryRow(_ category: MonthlyCategorySummary) -> some View {
		HStack {
			Label(category.name, systemImage: category.iconName)
			
			Spacer()
			
			Text(ServiceDurationFormatter.string(from: category.duration))
				.monospacedDigit()
				.foregroundStyle(.secondary)
		}
	}
	
	func bibleStudiesRow(_ count: Int) -> some View {
		HStack {
			Label("report.bible-studies", systemImage: "book")
			
			Spacer()
			
			Text(String(count))
				.monospacedDigit()
				.foregroundStyle(.secondary)
		}
	}
}

#Preview {
	NavigationStack {
		ScrollView {
			ServiceYearMonthRow(month: ReportPreviewFixtures.monthWithActivity)
		}
		.padding()
		.background(Color(.systemGroupedBackground))
	}
	.modelContainer(.preview)
}
