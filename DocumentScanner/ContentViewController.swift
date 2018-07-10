//
//  ContentViewController.swift
//  DocumentScanner
//
//  Created by Shengbo Lou on 7/10/18.
//  Copyright © 2018 Shengbo Lou. All rights reserved.
//

import UIKit

class ContentViewController: UIViewController {

    @IBOutlet var contentText: UITextView!
    var text:String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.contentText.text = text
        // Do any additional setup after loading the view.
    }

    @IBAction func donePressed(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}
