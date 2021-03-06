
import WatchKit
import ClockKit
import WatchConnectivity

let shortDateFormatter = { () -> NSDateFormatter in
	let d = NSDateFormatter()
	d.dateStyle = NSDateFormatterStyle.ShortStyle
	d.timeStyle = NSDateFormatterStyle.ShortStyle
	d.doesRelativeDateFormatting = true
	return d
	}()

final class GlanceController: WKInterfaceController, WCSessionDelegate {

    @IBOutlet weak var totalCount: WKInterfaceLabel!
	@IBOutlet var totalGroup: WKInterfaceGroup!
	@IBOutlet var errorText: WKInterfaceLabel!

	@IBOutlet weak var myCount: WKInterfaceLabel!
	@IBOutlet weak var myGroup: WKInterfaceGroup!

	@IBOutlet weak var mergedCount: WKInterfaceLabel!
	@IBOutlet weak var mergedGroup: WKInterfaceGroup!

	@IBOutlet weak var closedCount: WKInterfaceLabel!
	@IBOutlet weak var closedGroup: WKInterfaceGroup!

	@IBOutlet weak var participatedCount: WKInterfaceLabel!
	@IBOutlet weak var participatedGroup: WKInterfaceGroup!

	@IBOutlet weak var otherCount: WKInterfaceLabel!
	@IBOutlet weak var otherGroup: WKInterfaceGroup!

	@IBOutlet weak var unreadCount: WKInterfaceLabel!
	@IBOutlet weak var unreadGroup: WKInterfaceGroup!

	@IBOutlet weak var lastUpdate: WKInterfaceLabel!

	@IBOutlet weak var prIcon: WKInterfaceImage!
	@IBOutlet weak var issueIcon: WKInterfaceImage!

	private var showIssues: Bool = false

	override func awakeWithContext(context: AnyObject?) {
		super.awakeWithContext(context)
		errorText.setText("Loading...")
		setErrorMode(true)
	}

	override func willActivate() {
		super.willActivate()

		let session = WCSession.defaultSession()
		session.delegate = self
		session.activateSession()

		if session.iOSDeviceNeedsUnlockAfterRebootForReachability {
			errorText.setText("Please unlock your iPhone first")
			setErrorMode(true)
		} else if session.receivedApplicationContext.count > 0 {
			self.updateFromContext(session.receivedApplicationContext)
		}
	}

	func session(session: WCSession, didReceiveApplicationContext applicationContext: [String : AnyObject]) {
		dispatch_async(dispatch_get_main_queue()) {
			self.updateFromContext(applicationContext)
		}
	}

	func sessionReachabilityDidChange(session: WCSession) {
		dispatch_async(dispatch_get_main_queue()) {
			self.updateFromContext(session.receivedApplicationContext)
		}
	}

	private func updateFromContext(applicationContext: [String : AnyObject]) {
		if let result = applicationContext["overview"] as? [String : AnyObject] {

			showIssues = result["preferIssues"] as! Bool
			prIcon.setHidden(showIssues)
			issueIcon.setHidden(!showIssues)

			let r = result[showIssues ? "issues" : "prs"] as! [String : AnyObject]

			let tc = r["total"] as! Int
			totalCount.setText("\(tc)")

			let mc = r[PullRequestSection.Mine.apiName()]?["total"] as! Int
			myCount.setText("\(mc) \(PullRequestSection.Mine.watchMenuName().uppercaseString)")
			myGroup.setAlpha(mc==0 ? 0.4 : 1.0)

			let pc = r[PullRequestSection.Participated.apiName()]?["total"] as! Int
			participatedCount.setText("\(pc) \(PullRequestSection.Participated.watchMenuName().uppercaseString)")
			participatedGroup.setAlpha(pc==0 ? 0.4 : 1.0)

			if !showIssues {
				let rc = r[PullRequestSection.Merged.apiName()]?["total"] as! Int
				mergedCount.setText("\(rc) \(PullRequestSection.Merged.watchMenuName().uppercaseString)")
				mergedGroup.setAlpha(rc==0 ? 0.4 : 1.0)
			}

			let cc = r[PullRequestSection.Closed.apiName()]?["total"] as! Int
			closedCount.setText("\(cc) \(PullRequestSection.Closed.watchMenuName().uppercaseString)")
			closedGroup.setAlpha(cc==0 ? 0.4 : 1.0)

			let oc = r[PullRequestSection.All.apiName()]?["total"] as! Int
			otherCount.setText("\(oc) \(PullRequestSection.All.watchMenuName().uppercaseString)")
			otherGroup.setAlpha(oc==0 ? 0.4 : 1.0)

			let uc = r["unread"] as! Int
			if uc==0 {
				unreadCount.setText("NONE UNREAD")
				unreadGroup.setAlpha(0.3)
			} else if uc==1 {
				unreadCount.setText("1 COMMENT")
				unreadGroup.setAlpha(1.0)
			} else {
				unreadCount.setText("\(uc) COMMENTS")
				unreadGroup.setAlpha(1.0)
			}

			let lastRefresh = result["lastUpdated"] as! NSDate
			if lastRefresh.isEqualToDate(never()) {
				lastUpdate.setText("Not refreshed yet")
			} else {
				lastUpdate.setText(shortDateFormatter.stringFromDate(lastRefresh))
			}

			errorText.setText(nil)
			setErrorMode(false)

			updateComplications()
		}
	}

	private func setErrorMode(mode: Bool) {
		myGroup.setHidden(mode)
		participatedGroup.setHidden(mode)
		mergedGroup.setHidden(mode ? mode : showIssues)
		closedGroup.setHidden(mode)
		otherGroup.setHidden(mode)
		unreadGroup.setHidden(mode)
		totalGroup.setHidden(mode)
		lastUpdate.setHidden(mode)
		errorText.setHidden(!mode)
	}

	private func updateComplications() {
		let complicationServer = CLKComplicationServer.sharedInstance()
		if let activeComplications = complicationServer.activeComplications {
			for complication in activeComplications {
				complicationServer.reloadTimelineForComplication(complication)
			}
		}
	}
}
