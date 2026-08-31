//
//  EntryV11.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import SwiftData

extension SchemaV11 {
	@Model
	final class Entry {
		var date: Date = Date()
		var duration: TimeInterval = 0
		var bibleStudies: Int = 0
		
		var createdAt: Date = Date()
		
		@Relationship var tracker: Tracker?
		var storedTracker: EntryTracker? = nil
		
		/// Entry has been carried in from last month
		@Relationship var sourceSubmission: SubmittedReport?
		var sourceReportingLineID: String?
		var sourceReportYear: Int?
		var sourceReportMonth: Int?
		
		init(
			date: Date,
			duration: TimeInterval,
			tracker: Tracker?,
			bibleStudies: Int? = nil,
			source: (submission: SubmittedReport, lineID: String)? = nil,
		) {
			self.date = date
			self.duration = duration
			self.tracker = tracker
			self.bibleStudies = bibleStudies ?? 0
			
			if let tracker {
				let storedTracker = EntryTracker(name: tracker.name, icon: tracker.iconName, type: tracker.type)
				self.storedTracker = storedTracker
			}
			
			if let source {
				self.sourceSubmission = source.submission
				self.sourceReportingLineID = source.lineID
				
				self.sourceReportYear = source.submission.year
				self.sourceReportMonth = source.submission.month
			}
		}
		
		struct EntryTracker: Codable, Hashable, Identifiable {
			var name: String = ""
			var icon: String = "questionmark.circle"
			var type: TrackerType = .main
			
			init(name: String? = nil, icon: String? = nil, type: TrackerType? = nil) {
				if let name = name { self.name = name }
				if let icon = icon { self.icon = icon }
				if let type = type { self.type = type }
			}
			
			var id: String {
				return name
			}
		}
	}
}
