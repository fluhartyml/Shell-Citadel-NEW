//
//  Attribution.swift
//  Shell Citadel
//
//  Third-party credit, and the full licence texts those licences actually require.
//
//  ⚠️ WHY THE FULL TEXT AND NOT A THANK-YOU LINE. The MIT Licence requires the copyright
//  notice AND the permission notice to be included in copies. Apache 2.0 section 4
//  carries its own attribution duty and requires the NOTICE contents to travel with the
//  work. A one-line credit does not satisfy either, and the obligation attaches to the
//  BINARY — so About is where it has to live, not the README.
//
//  ⚠️ THE REBUILD DROPPED THIS ENTIRELY. The old app carried it from 2026-08-22; the new
//  project was created empty on 2026-09-04 and linked Citadel on day one with no notice
//  anywhere. Nothing failed and nothing warned — a licence obligation is invisible until
//  somebody looks, which is why it is worth writing down that it was missed.
//
//  ⚠️ EVERY LINE BELOW WAS READ OFF THE RESOLVED CHECKOUTS ON 2026-09-04, NOT RECALLED.
//  Package.resolved lists TEN packages, not the two the old file named — Citadel pulls
//  eight more in behind it. Doing this from memory would have shipped a list that was
//  80% incomplete and, in one case, wrong about who wrote the code.
//

import Foundation

enum Attribution {

    /// Shown at the top of the About sheet. Michael's call, 2026-08-22: name the author,
    /// name the licence, and say plainly that this app is not official.
    static let disclaimer = """
    Shell Citadel is not affiliated with, endorsed by, or an official product of the \
    Citadel project, Apple Inc., or any other project named here. Each remains the \
    intellectual property of its authors.
    """

    struct Component: Identifiable {
        var id: String { name }
        let name: String
        let url: String
        let holder: String
        let license: String
        let text: String
    }

    /// ⚠️ ORDER IS DELIBERATE: what the app talks to directly first, then what those pull
    /// in. Somebody scanning this wants to know what SSH library is in here, not to hunt
    /// for it alphabetically among its dependencies.
    static let components: [Component] = [
        Component(name: "Citadel",
                  url: "https://github.com/orlandos-nl/Citadel",
                  holder: "Copyright \u{00A9} 2022 Orlandos",
                  license: "MIT Licence",
                  text: mit(holder: "Copyright (c) 2022 Orlandos")),

        // ⚠️ THIS IS A FORK, AND NAMING APPLE HERE WOULD BE WRONG.
        //
        // The old app's attribution pointed at github.com/apple/swift-nio-ssh. What this
        // app actually resolves and links is github.com/Wellz26/swift-nio-ssh — read out
        // of Package.resolved, not assumed. The code is still Apache 2.0 and still
        // authored by the SwiftNIO project, so the copyright line is Apple's; but the URL
        // has to point at what shipped, or the notice sends someone to source that is not
        // the source in this binary.
        Component(name: "SwiftNIO SSH",
                  url: "https://github.com/Wellz26/swift-nio-ssh",
                  holder: "Copyright \u{00A9} Apple Inc. and the SwiftNIO project authors \u{00B7} fork by Wellz26",
                  license: "Apache Licence 2.0",
                  text: apache(project: "SwiftNIO SSH",
                               notice: "Copyright 2019, Apple Inc. and the SwiftNIO project authors.")),

        Component(name: "SwiftNIO",
                  url: "https://github.com/apple/swift-nio",
                  holder: "Copyright \u{00A9} 2017, 2018 The SwiftNIO Project",
                  license: "Apache Licence 2.0",
                  text: apache(project: "SwiftNIO",
                               notice: "Copyright 2017, 2018 The SwiftNIO Project.")),

        Component(name: "Swift Crypto",
                  url: "https://github.com/apple/swift-crypto",
                  holder: "Copyright \u{00A9} 2019 The SwiftCrypto Project",
                  license: "Apache Licence 2.0",
                  text: apache(project: "Swift Crypto",
                               notice: "Copyright 2019 The SwiftCrypto Project.")),

        Component(name: "SwiftASN1",
                  url: "https://github.com/apple/swift-asn1",
                  holder: "Copyright \u{00A9} 2022 The SwiftASN1 Project",
                  license: "Apache Licence 2.0",
                  text: apache(project: "SwiftASN1",
                               notice: "Copyright 2022 The SwiftASN1 Project.")),

        Component(name: "Swift Log",
                  url: "https://github.com/apple/swift-log",
                  holder: "Copyright \u{00A9} 2018, 2019 The SwiftLog Project",
                  license: "Apache Licence 2.0",
                  text: apache(project: "Swift Log",
                               notice: "Copyright 2018, 2019 The SwiftLog Project.")),

        Component(name: "Swift Atomics",
                  url: "https://github.com/apple/swift-atomics",
                  holder: "Copyright \u{00A9} Apple Inc. and the Swift project authors",
                  license: "Apache Licence 2.0",
                  text: apache(project: "Swift Atomics",
                               notice: "Copyright Apple Inc. and the Swift project authors.")),

        Component(name: "Swift Collections",
                  url: "https://github.com/apple/swift-collections",
                  holder: "Copyright \u{00A9} Apple Inc. and the Swift project authors",
                  license: "Apache Licence 2.0",
                  text: apache(project: "Swift Collections",
                               notice: "Copyright Apple Inc. and the Swift project authors.")),

        Component(name: "Swift System",
                  url: "https://github.com/apple/swift-system",
                  holder: "Copyright \u{00A9} Apple Inc. and the Swift project authors",
                  license: "Apache Licence 2.0",
                  text: apache(project: "Swift System",
                               notice: "Copyright Apple Inc. and the Swift project authors.")),

        Component(name: "BigInt",
                  url: "https://github.com/attaswift/BigInt",
                  holder: "Copyright \u{00A9} 2016\u{2013}2017 K\u{00E1}roly L\u{0151}rentey",
                  license: "MIT Licence",
                  text: mit(holder: "Copyright (c) 2016-2017 K\u{00E1}roly L\u{0151}rentey")),
    ]

    // MARK: - The texts

    /// ⚠️ THE COPYRIGHT LINE IS A PARAMETER because MIT requires *that holder's* notice,
    /// not a generic one. Two MIT components with the same text and different holders is
    /// two notices, not one.
    static func mit(holder: String) -> String {
        """
        MIT License

        \(holder)

        Permission is hereby granted, free of charge, to any person obtaining a copy of \
        this software and associated documentation files (the "Software"), to deal in the \
        Software without restriction, including without limitation the rights to use, \
        copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the \
        Software, and to permit persons to whom the Software is furnished to do so, \
        subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all \
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS \
        FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR \
        COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN \
        AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION \
        WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
        """
    }

    /// The Apache 2.0 short-form notice, plus that project's own NOTICE line.
    ///
    /// ⚠️ SECTION 4 WANTS BOTH. The licence reference alone is not enough where the
    /// project ships a NOTICE file — its contents have to travel with the work. Every
    /// line passed in here was read out of that package's own NOTICE.txt.
    static func apache(project: String, notice: String) -> String {
        """
        \(project)

        \(notice)

        Licensed under the Apache License, Version 2.0 (the "License"); you may not use \
        this file except in compliance with the License. You may obtain a copy of the \
        License at:

            http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software distributed \
        under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR \
        CONDITIONS OF ANY KIND, either express or implied. See the License for the \
        specific language governing permissions and limitations under the License.
        """
    }
}
