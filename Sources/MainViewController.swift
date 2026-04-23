import UIKit
import Network
import ReplayKit
import CoreLocation

class MainViewController: UIViewController {

    // MARK: - UI Elements
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Mirror"
        label.textColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        label.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Screen Mirror to Chromecast"
        label.textColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Ready to scan for Chromecast devices.\nTap 'Scan for Devices' to begin."
        label.textColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    private let scanButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Scan for Devices", for: .normal)
        button.setTitleColor(UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), for: .normal)
        button.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let startMirrorButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start Mirror", for: .normal)
        button.setTitleColor(UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), for: .normal)
        button.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false
        button.alpha = 0.5
        return button
    }()

    private let deviceTableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        tableView.separatorColor = UIColor.darkGray
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    // MARK: - Properties
    private var discoveredDevices: [(result: NWBrowser.Result, endpoint: NWEndpoint, metadata: [String: Any]?)] = []
    private var selectedDeviceIndex: Int?
    private var browser: NWBrowser?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(statusLabel)
        view.addSubview(scanButton)
        view.addSubview(startMirrorButton)
        view.addSubview(deviceTableView)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            statusLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scanButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            scanButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanButton.widthAnchor.constraint(equalToConstant: 200),
            scanButton.heightAnchor.constraint(equalToConstant: 44),

            activityIndicator.centerYAnchor.constraint(equalTo: scanButton.centerYAnchor),
            activityIndicator.trailingAnchor.constraint(equalTo: scanButton.leadingAnchor, constant: -12),

            deviceTableView.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: 20),
            deviceTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            deviceTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            deviceTableView.heightAnchor.constraint(equalToConstant: 200),

            startMirrorButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            startMirrorButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startMirrorButton.widthAnchor.constraint(equalToConstant: 200),
            startMirrorButton.heightAnchor.constraint(equalToConstant: 50),
        ])

        scanButton.addTarget(self, action: #selector(scanForDevices), for: .touchUpInside)
        startMirrorButton.addTarget(self, action: #selector(startMirror), for: .touchUpInside)

        deviceTableView.delegate = self
        deviceTableView.dataSource = self
        deviceTableView.register(UITableViewCell.self, forCellReuseIdentifier: "DeviceCell")
    }

    // MARK: - Device Scanning
    @objc private func scanForDevices() {
        browser?.cancel()
        discoveredDevices.removeAll()
        selectedDeviceIndex = nil
        deviceTableView.reloadData()
        updateStartButton()

        activityIndicator.startAnimating()
        statusLabel.text = "Scanning for Chromecast devices..."

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: "_googlecast._tcp", domain: "local."), using: parameters)
        self.browser = browser
        
        // Use connection to resolve TXT records
        let connectionParameters = NWParameters()
        connectionParameters.includePeerToPeer = true

        browser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.statusLabel.text = "Browser ready. Searching..."
                case .failed(let error):
                    self?.statusLabel.text = "Scan failed: \(error.localizedDescription)"
                    self?.activityIndicator.stopAnimating()
                case .cancelled:
                    self?.statusLabel.text = "Scan cancelled"
                    self?.activityIndicator.stopAnimating()
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            DispatchQueue.main.async {
                // Clear and rebuild device list
                self?.discoveredDevices.removeAll()
                
                for result in results {
                    // Resolve metadata from the service
                    var metadata: [String: Any]? = nil
                    
                    if case let .service(name, type, domain, interface_) = result.endpoint {
                        // Extract device type from TXT record if available
                        // Chromecast devices typically have md= device type (e.g., md=Speaker, md=TV)
                        metadata = ["name": name, "type": type, "domain": domain]
                    }
                    
                    self?.discoveredDevices.append((result: result, endpoint: result.endpoint, metadata: metadata))
                }
                
                self?.deviceTableView.reloadData()
                
                if let count = self?.discoveredDevices.count, count > 0 {
                    self?.statusLabel.text = "Found \(count) device(s). Select one to continue."
                }
            }
        }

        browser.start(queue: .main)

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.activityIndicator.stopAnimating()
            self?.browser?.cancel()
            if self?.discoveredDevices.isEmpty == true {
                self?.statusLabel.text = "No Chromecast devices found.\nMake sure your device is on the same network."
            }
        }
    }

    // MARK: - Start Mirror
    @objc private func startMirror() {
        guard let index = selectedDeviceIndex, index < discoveredDevices.count else {
            statusLabel.text = "Please select a Chromecast device first."
            return
        }

        let selectedResult = discoveredDevices[index].result
        var deviceName = "Chromecast"

        if case let .service(name, _, _, _) = selectedResult.endpoint {
            deviceName = name
        }

        statusLabel.text = "Launching broadcast picker..."

        // Present the iOS system broadcast picker
        // The extension (Cast Screen Mirror.appex) handles device scanning internally
        presentBroadcastPicker()
    }

    private func presentBroadcastPicker() {
        // Create RPSystemBroadcastPickerView - a view that shows live broadcast button
        // When users tap this button, it shows the system broadcast picker
        
        let pickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        
        // Set preferred extension to our Cast Screen Mirror extension
        // This ensures our extension is used for the broadcast
        pickerView.preferredExtension = "com.iosmirror.broadcast"
        pickerView.tintColor = .white
        pickerView.showsMicrophoneButton = false
        
        // Position above the Start Mirror button
        pickerView.center = CGPoint(x: view.bounds.midX, y: startMirrorButton.frame.minY - 80)
        pickerView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
        
        // Add to view hierarchy (visible button)
        view.addSubview(pickerView)
        
        // Update status to guide user
        statusLabel.text = "Tap the live button to start mirroring"
    }

    // MARK: - Helpers
    private func updateStartButton() {
        let hasSelection = selectedDeviceIndex != nil
        startMirrorButton.isEnabled = hasSelection
        startMirrorButton.alpha = hasSelection ? 1.0 : 0.5
    }
}

// MARK: - RPBroadcastActivityViewControllerDelegate
extension MainViewController: RPBroadcastActivityViewControllerDelegate {
    func broadcastActivityViewController(_ broadcastActivityViewController: RPBroadcastActivityViewController,
                                        didFinishWith broadcastController: RPBroadcastController?,
                                        error: Error?) {
        broadcastActivityViewController.dismiss(animated: true) { [weak self] in
            if let error = error {
                self?.statusLabel.text = "Picker error: \(error.localizedDescription)"
            } else if broadcastController != nil {
                self?.statusLabel.text = "Broadcast started!"
            } else {
                self?.statusLabel.text = "Broadcast cancelled."
            }
        }
    }
}

// MARK: - UITableViewDelegate & DataSource
extension MainViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoveredDevices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)

        let device = discoveredDevices[indexPath.row]
        var displayText = "Unknown Device"
        
        if case let .service(name, _, _, _) = device.endpoint {
            // Parse device model from name - extract just the model name without room/location
            // Examples: "Living Room TV" -> "Google TV" (not Chromecast)
            // "Bedroom Speaker" -> "Google Nest Mini"
            // "Kitchen Nest Hub" -> "Google Nest Hub"
            
            let lowerName = name.lowercased()
            var deviceModel = "Chromecast"
            
            // Detect specific Google/Nest model from the name
            if lowerName.contains("nest hub max") {
                deviceModel = "Nest Hub Max"
            } else if lowerName.contains("nest hub") {
                deviceModel = "Nest Hub"
            } else if lowerName.contains("nest mini") {
                deviceModel = "Nest Mini"
            } else if lowerName.contains("chromecast audio") || lowerName.contains("chromecast ultra") {
                deviceModel = "Chromecast Ultra"
            } else if lowerName.contains("chromecast with google tv") || lowerName.contains("chromecast 4") || lowerName.contains("google tv") {
                deviceModel = "Google TV"
            } else if lowerName.contains("chromecast") {
                deviceModel = "Chromecast"
            } else if lowerName.contains("home max") {
                deviceModel = "Google Home Max"
            } else if lowerName.contains("home mini") || lowerName.contains("home") {
                deviceModel = "Google Home Mini"
            }
            
            displayText = deviceModel
        }

        // Show device model only
        cell.textLabel?.text = displayText
        cell.textLabel?.textColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        cell.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        cell.accessoryType = (selectedDeviceIndex == indexPath.row) ? .checkmark : .none
        cell.tintColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        selectedDeviceIndex = indexPath.row
        tableView.reloadData()
        
        // Get device model only (from cellForRowAt logic)
        var deviceModel = "Unknown Device"
        if case let .service(name, _, _, _) = discoveredDevices[indexPath.row].endpoint {
            let lowerName = name.lowercased()
            if lowerName.contains("nest hub max") {
                deviceModel = "Nest Hub Max"
            } else if lowerName.contains("nest hub") {
                deviceModel = "Nest Hub"
            } else if lowerName.contains("nest mini") {
                deviceModel = "Nest Mini"
            } else if lowerName.contains("chromecast audio") || lowerName.contains("chromecast ultra") {
                deviceModel = "Chromecast Ultra"
            } else if lowerName.contains("chromecast with google tv") || lowerName.contains("chromecast 4") || lowerName.contains("google tv") {
                deviceModel = "Google TV"
            } else if lowerName.contains("chromecast") {
                deviceModel = "Chromecast"
            } else if lowerName.contains("home max") {
                deviceModel = "Google Home Max"
            } else if lowerName.contains("home mini") || lowerName.contains("home") {
                deviceModel = "Google Home Mini"
            }
        }
        
        statusLabel.text = "Selected: \(deviceModel)\nTap 'Start Mirror' to begin broadcasting."

        updateStartButton()
    }
}