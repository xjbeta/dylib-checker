//
//  ViewController.swift
//  dylib checker
//
//  Created by xjbeta on 4/11/22.
//

import Cocoa
import SwiftSlash

class ViewController: NSViewController {
    
    @IBOutlet weak var tableView: NSTableView!
    
    class Dylib: NSObject {
        @objc dynamic let name: String
        @objc dynamic var minos = ""
        
        init(name: String) {
            self.name = name
        }
    }
    
    @objc dynamic var libsList = [Dylib]()
    
    @IBOutlet weak var pathTextField: NSTextField!
    
    @IBOutlet weak var selectButton: NSButton!
    @IBAction func selectFolder(_ sender: NSButton) {
        openPanel.begin { re in
            Task {
                guard re == .OK, let url = self.openPanel.url else { return }
                self.pathTextField.stringValue = "Loading"
                self.libsList.removeAll()
                await self.checkMinOS(url)
                self.pathTextField.stringValue = url.path
            }
        }
    }
    
    lazy var openPanel: NSOpenPanel = {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        return panel
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func checkMinOS(_ url: URL) async {
        do {
            var cmd = Command(bash:"zsh -li -c 'for lib in *; do (otool -l $lib); done'")
            cmd.workingDirectory = url
            let re = try await cmd.runSync()
            guard re.exitCode == 0 else { return }
            let out = re.stdout.compactMap {
                String(data: $0, encoding: .utf8)
            }
            
            var list = [Dylib]()
            var dylib: Dylib?
            
            out.enumerated().forEach {
                var minos = ""
                if $0.element.hasSuffix(".dylib:") {
                    let name = String($0.element.dropLast())
                    dylib = .init(name: name)
                } else if $0.element.hasSuffix("LC_VERSION_MIN_MACOSX") {
                    minos = out[$0.offset + 2]
                } else if $0.element.hasSuffix("LC_BUILD_VERSION") {
                    minos = out[$0.offset + 3]
                }
                
                if dylib != nil, minos != "" {
                    dylib?.minos = String(minos.dropFirst(10))
                    list.append(dylib!)
                    dylib = nil
                }
            }
            
            libsList = list.sorted(by: {
                return ($0.name as NSString).deletingPathExtension.compare(($1.name as NSString).deletingPathExtension, options: .numeric) == .orderedAscending
             })
        } catch let error {
            print(error)
        }
    }
}
