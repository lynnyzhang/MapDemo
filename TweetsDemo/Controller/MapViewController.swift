//
//  ViewController.swift
//  TweetsDemo
//
//  Created by Ying Zhang on 3/6/19.
//  Copyright © 2019 Ying Zhang. All rights reserved.
//

import UIKit

import CoreLocation
import AddressBook
import MessageUI

public let fontSize: CGFloat = 17

// TODO: refactor 💥
class MapViewController: UIViewController {
	
	fileprivate var contentView: DashboardMapView {
		return view as! DashboardMapView
	}
	
	private(set) var commandContainer = UIView()
	private(set) var mapCommandDrawer = DashboardMapCommandDrawerController()
	
	fileprivate var lastLocation: CLLocation?
	private(set) var eventManager = ConcreteNotificationEventManager.sharedInstance
	private(set) var bluetoothStatusService = BluetoothStatusService.shared
	fileprivate var locationManager = CLLocationManager()
	
	//TODO: Improvement - Make a date formatter reusable everywhere.
	fileprivate lazy var dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.timeStyle = DateFormatter.Style.short
		formatter.dateStyle = DateFormatter.Style.none
		formatter.locale = kDefaultLocale
		return formatter
	}()
	
	private(set) var deviceReader: DeviceReaderProtocol = DeviceYapStorage()
	private var commandReader: DashboardCommandReaderProtocol = DashboardCommandYapStorage()
	private var messageFormatter: CommandMessageFormatterProtocol = CommandMessageFormatter()
	
	var lastSpinningButton: SpinnerProgressButton? {
		return mapCommandDrawer.contentView.getLastSpinningButton()
	}
	
	let mapDashboardTransitionManager = MapDashboardTransitionManager()
	
	let dashboardCommandController = DashboardCommandController.sharedInstance
	var network: DCCSNetworkAccessControlProxy = DCCSNetworkAccessControlProxy(decorated: DCCSNetwork())
	
	private let tracker = Tracker.sharedInstance
	private let screenName = "MapDashboard"
	
	fileprivate var runtimeTickingTimer: Timer?
	
	/// Handles actions, logic related to the mapView
	private(set) var mapViewManager : (MapViewManagerProtocol & MapViewManagerActionProtocol)?
	
	// RX
	let disposeBag = DisposeBag()
	let commandObservable = PublishSubject<CommandStatus>()
	
	// MARK: - View Lifecycle
	
	deinit {
		NotificationCenter.default.removeObserver(self)
		
		SSLogger.log("MapDashboardBaseViewController was deinit.")
	}
	
	override func loadView() {
		view = MapDashboardBaseView()
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		loadDashboardNavigationTitleView()
		removeActivityButtonIfBluetoothOnly()
		initializeMapManager()
		setupEventManager()
		observeAppBTChanged()
		setupDashboardCommandControllerListeners()
		DashboardAppRatingHelper.displayAlertVC(onDashboardViewController: self, selectedDevice: deviceReader.selectedDevice)
		createObserversActions()
		listenForCommandStatus()
	}
	
	private func listenForCommandStatus() {
		commandObservable.subscribe({ [weak self] (command) in
			guard let commandStatus = command.element else { return }
			self?.mapCommandDrawer.toggleInteractionsForRunningCommand(enabled: !commandStatus.inProgress)
		}).disposed(by: disposeBag)
		
		_ = NewVehicleService.newDevices
			.subscribe(onNext: { (newVehicle) in
				debugPrint("We have new vehicles")
				
				NewVehicleService.shared.showNewVehicleInController(self)
			})
			.disposed(by: disposeBag)
		NewVehicleService.checkNewDevices.value = true
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		contentView.mapViewContainer.carLocationButton.setImage(deviceReader.selectedDevice.vehicle?.vehicleIconType.buttonIcon(), for: .normal)
		setupActivityButtonBadge()
		getRecentActivities()
		
		// will restart runtime ticking if required
		displayLastCommand()
		
		contentView.smartParkView.button.on = MapYapStorage.mapDeviceInfoForSelectedDevice.isSmartParked
		displayHelpViewFirstTime(HelpImageName.imageForCurrentDashboard(dashboardMode: AppSettingsYapStorage.dashboardMode), onDismiss: nil)
		
		/// NOTE: Shanhe
		/// Somehow different from the classic/modern dashboard which init by storyboard,
		/// viewDidLoad on this VC is called before the VC being added to a navigation controller
		/// so that `loadDashboardNavigationTitleView` isn't able to do it
		/// that's why I repeate it here.
		if let navController = navigationController as? ViperNavigationController {
			navController.statusBarShade?.backgroundColor = UIColor(white: 0, alpha: 0.5)
		}
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		tracker.trackScreen(screenName)
		contentView.setupBluetoothButton(BluetoothYapStorage.isEnabled)
		mapViewManager?.updateScreenWithCurrentMapDeviceInfo(refreshLocation: false, completion: nil)
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		runtimeTickingTimer?.invalidate()
		runtimeTickingTimer = nil
		super.viewDidDisappear(animated)
	}
	
	/// Initialize the mapView manager with it's mapView and delegate
	private func initializeMapManager() {
		mapViewManager = MapViewManager(mapView: contentView.mapViewContainer.mapView, buttonDelegate: contentView.mapViewContainer)
	}
	
	// MARK: - Private methods
	
	private func setupEventManager() {
		// Observe when the user change it's vehicle from status.
		NotificationCenter.default.addObserver(self, selector: #selector(hideSmartStartSuccessMessage), name: NSNotification.Name(rawValue: DashboardConstants.Notifications.hideCommandLabelNotification), object: nil)
		
		self.eventManager.onActivityRefreshedAfterNotificationReceived.subscribe(onNext: { [weak self] _ in
			guard let self = self else { return }
			
			self.setupActivityButtonBadge()
		}).disposed(by: self.disposeBag)
		
		// Observe when the user leave vehicle status. If he changed the aux buttons of the car, or changed the car we need to refresh aux buttons with animation
		self.eventManager.onCloseVehicleStatusView.subscribe(onNext: { [weak self] device in
			guard let self = self else { return }
			
			self.mapCommandDrawer.setupAuxButtons(animated: true)
		}).disposed(by: self.disposeBag)
	}
	
	/// Subscribe to RX bluetooth status observer
	private func observeAppBTChanged() {
		bluetoothStatusService.appBluetoothEnabled.subscribe(onNext: { [weak self] (enabled) in
			self?.contentView.setupBluetoothButton(enabled)
		}).disposed(by: disposeBag)
	}
	
	/// Create RX observers for smartPark button and mapView tap actions
	private func createObserversActions() {
		contentView.smartParkView.button.rx.tapGesture().when(.recognized).subscribe(onNext: { [weak self](tapGesture) in
			guard let self = self else { return }
			self.didSmartParkButtonPress(self.contentView.smartParkView.button)
		}).disposed(by: disposeBag)
	}
	
	private func setupDashboardCommandControllerListeners() {
		dashboardCommandController.onCommandCompleted.subscribe(onNext: { [weak self] lastCommandExecuted in
			guard let self = self else { return }
			
			DispatchQueue.main.async {
				if case .failed = lastCommandExecuted.status {
					self.executeOnCommandCompleteError(lastCommandExecuted)
					self.commandObservable.onNext(.failed)
				} else {
					self.executeOnCommandCompleteSuccess(lastCommandExecuted)
					self.commandObservable.onNext(.executed)
					// For non GPS vehicle, if lock or unlock is success, we want to turn on/off smartPark
					// This will be probably be asked by the client, but not on this sprint. Leave it there for now
					// There is a small bug to fix on unlock also
					
					//				if self?.deviceReader.selectedDevice.hasGPS == false {
					//					if case .common(let cmd, _, _) = lastCommandExecuted.command, (cmd == .Lock || cmd == .Unlock) {
					//						self?.setSmartParkOnCommand()
					//					}
					//				}
				}
			}
		}).disposed(by: self.disposeBag)
		
		dashboardCommandController.onCommandExecute = { [weak self] (command: String) in
			self?.hideSmartStartSuccessMessage()
			self?.commandObservable.onNext(.inProgress)
		}
	}
	
	/// Turn on/off smartPark when user lock/unlock his car
	//	Feature not enabled or now, just leave it there it will be used soon
	func setSmartParkOnCommand() {
		didSmartParkButtonPress(contentView.smartParkView.button)
	}
	
	
	/// Update the lastCommand and runtime labels once a response is received for a command.
	private func displayLastCommand() {
		guard let lastCommand = commandReader.getLastCommand() else { return }
		
		if case .common(let cmd, _, _) = lastCommand.command, cmd == .Aux1 {
			lastCommand.userInfo = CarSettingsYapStorage.getCarSettings(deviceReader.selectedDevice.assetId!).auxButtons.first?.name ?? ""
		} else if case .common(let cmd, _, _) = lastCommand.command, cmd == .Aux2 {
			lastCommand.userInfo = CarSettingsYapStorage.getCarSettings(deviceReader.selectedDevice.assetId!).auxButtons.last?.name ?? ""
		}
		
		// because we update the UI, is beter to execute in main/UI thread
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }
			
			if self.isValidRuntimeTicking() {
				self.startRuntimeTicking()
			} else {
				if !self.messageFormatter.message(forCommand: lastCommand, displayRuntimeError: self.commandReader.shouldDisplayRuntimeError()).string.isEmpty {
					self.mapCommandDrawer.contentView.setLastCommandLabel(withText: self.messageFormatter.message(forCommand: lastCommand, displayRuntimeError: self.commandReader.shouldDisplayRuntimeError(), fontSize: fontSize))
				}
				self.mapCommandDrawer.contentView.setRuntimeMessageLabel(withText: NSAttributedString(string: ""))
				self.mapCommandDrawer.contentView.setRuntimeCountdownLabel(withText: NSAttributedString(string: ""))
				self.mapCommandDrawer.contentView.setLastCommandLabel(hidden: false)
			}
		}
	}
	
	/// Hide the commandDrawer labels.
	@objc func hideSmartStartSuccessMessage() {
		mapCommandDrawer.contentView.setLastCommandLabel(hidden: true)
		mapCommandDrawer.contentView.setRuntimeLabels(hidden: true)
		
		mapCommandDrawer.contentView.setLastCommandLabel(withText: NSAttributedString())
	}
	
	/// Display runtime labels and start the counter if available
	private func startRuntimeTicking() {
		mapCommandDrawer.contentView.setLastCommandLabel(hidden: false)
		mapCommandDrawer.contentView.setRuntimeLabels(hidden: false)
		onRuntimeTicking()
		
		if runtimeTickingTimer == nil {
			runtimeTickingTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(MapDashboardBaseViewController.onRuntimeTicking), userInfo: nil, repeats: true)
		}
	}
	
	/// Stop the runtime counter and update the last command displayed
	private func stopRuntimeTicking(assetID: Int64) {
		runtimeTickingTimer?.invalidate()
		runtimeTickingTimer = nil
		
		EngineStatusManager.sharedInstance.discardRuntimeCountdown(assetID: assetID)
		displayLastCommand()
	}
	
	/// Check if the last command is runtime and it's possible to have a runtime
	///
	/// - Returns: Bool - true if the car can show runtime
	private func isValidRuntimeTicking() -> Bool {
		guard let assetID = self.deviceReader.selectedDevice.assetId, let lastCommand = EngineStatusManager.sharedInstance.lastCommandsExecuted[assetID] else { return false }
		guard case .common(let cmd, _, _) = lastCommand.command, lastCommand.status == .executed && cmd == .ReqRuntime else { return false }
		
		return EngineStatusManager.sharedInstance.hasRuntimeCountdown(assetID: assetID)
	}
	
	/// Update the runtime labels while runtime is on
	@objc func onRuntimeTicking() {
		guard let assetID = self.deviceReader.selectedDevice.assetId else { return }
		guard isValidRuntimeTicking() else {
			stopRuntimeTicking(assetID: assetID)
			return
		}
		
		let countdown = Int(EngineStatusManager.sharedInstance.getCountdown(assetID: assetID))
		let minutes = String(format: "%02d", (countdown % 3600) / 60)
		let seconds = String(format: "%02d", countdown % 60)
		
		let stringMessage = NSAttributedString(string: String(format: LocalizedString.Dashboard.Message.RuntimeRunning), attributes: [NSAttributedString.Key.font: Font.ProximaNovaLight(fontSize)])
		let stringCountdown = NSAttributedString(string: "\(minutes):\(seconds)", attributes: [NSAttributedString.Key.font: Font.ProximaNovaLight(fontSize).monospacedDigitFont])
		
		if let lastCommand = self.commandReader.getLastCommand() {
			let commandStringMessage = NSMutableAttributedString(attributedString: self.messageFormatter.message(forCommand: lastCommand, displayRuntimeError: false, fontSize: fontSize))
			self.mapCommandDrawer.contentView.setLastCommandLabel(withText: commandStringMessage)
		}
		
		self.mapCommandDrawer.contentView.setRuntimeMessageLabel(withText: stringMessage)
		self.mapCommandDrawer.contentView.setRuntimeCountdownLabel(withText: stringCountdown)
	}
	
	fileprivate func executeOnCommandCompleteSuccess(_ lastCommandExecuted: LastCommandExecuted) {
		// The command is successfull, increment the count
		if case .executed = lastCommandExecuted.status {
			DashboardAppRatingHelper.incrementNumberCommands()
			// Try to display the rating alert
			DashboardAppRatingHelper.displayAlertVC(onDashboardViewController: self, selectedDevice: deviceReader.selectedDevice)
			lastSpinningButton?.commandSuccessful()
		}
		
		if lastCommandExecuted.isRemoteCommand {
			remoteCommandCompleted(lastCommandExecuted)
		}
		
		displayLastCommand()
	}
	
	func remoteCommandCompleted(_ command: LastCommandExecuted) {
		fatalError("RemoteCommandCompleted needs to be overriden")
	}
	
	private func executeOnCommandCompleteError(_ lastCommandExecuted: LastCommandExecuted) {
		displayLastCommand()
		if lastCommandExecuted.isRemoteCommand {
			remoteCommandCompleted(lastCommandExecuted)
		}
		lastSpinningButton?.commandFailed()
	}
	
	private func setupActivityButtonBadge() {
		let activityBadgeCount = ActivityRealmHelper.shared.countOfUnreadActivities
		var badgeString : String? = activityBadgeCount < maxBadgeNumber ? "\(activityBadgeCount)" : "99+"
		if ViperVideoTutorialConfiguration {
			badgeString = "\(VideoTutorialSettings.activityBadgeCount)"
		}
		if activityBadgeCount == 0 {
			badgeString = nil
		}
		contentView.mapViewContainer.setupActivityButtonBadge(withText: badgeString)
	}
	
	fileprivate func getRecentActivities() {
		guard !DeviceYapStorage.isBluetoothOnlyDevices else { return }
		if DeviceYapStorage.isBluetoothOnlyDevices { return }
		
		DispatchQueue.global(qos: .userInteractive).async {
			let activityReader = ActivityNetworkSaver(network: ActivityNetworkParallel())
			_ = activityReader.getRecentActivities(forDevices: DeviceYapStorage.devices)
		}
	}
	
	func didSmartParkButtonPress(_ button: OnOffSwitchButton) {
		let smartParked = MapYapStorage.mapDeviceInfoForSelectedDevice.isSmartParked
		
		// If smartParked, the button is on, so we want to change the state to off
		if smartParked {
			button.on = false
			resetViewToInitialState()
			return
		}
		button.loading = true
		
		if let kbLocation = mapViewManager?.userLocation, let location = kbLocation.location {
			mapViewManager?.saveOrUpdateMapDeviceInfo(location, isSmartParked: true)
			mapViewManager?.updateScreenWithCurrentMapDeviceInfo(refreshLocation: false, completion: { (success) in
				button.on = success
			})
		} else  {
			button.on = false
			UIAlertController.show(.settings(title: LocalizedString.Alert.Title.locationAccessDisabled, message: LocalizedString.Alert.Message.openSettingsToUseSmartPark, settingUrl: .main))
		}
	}
	
	/// Reset the view to an empty state, removing the car pin, reseting smartpark button to off and setting device smartpark to false
	private func resetViewToInitialState() {
		mapViewManager?.changeButton(.carLocation, state: false)
		contentView.mapViewContainer.mapView.removeAllAnnotationFromMap(false)
		mapViewManager?.saveOrUpdateMapDeviceInfo(CLLocation(latitude: 0, longitude: 0), isSmartParked: false)
	}
}

extension MapDashboardBaseViewController: MFMailComposeViewControllerDelegate {
	
	// MARK: MFMailComposeViewControllerDelegate
	
	func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
		controller.dismiss(animated: true, completion: nil)
	}
}

extension MapDashboardBaseViewController {
	
	fileprivate func removeActivityButtonIfBluetoothOnly() {
		if DeviceYapStorage.isBluetoothOnlyDevices {
			contentView.mapViewContainer.hideAlertButton()
		}
	}
}



class ViewController: UIViewController {

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
	}


}

extension MapViewController : MapLocationButtonActionDelegate {
	func didPressButton(_ button: ) {
		case .carLocation:
			mapViewManager?.carButtonTapped()
		case .userLocation:
			mapViewManager?.userLocationButtonTapped()
		case .mapDisplayType:
			mapViewManager?.switchViewTypeTapped()
		}
	}
}
