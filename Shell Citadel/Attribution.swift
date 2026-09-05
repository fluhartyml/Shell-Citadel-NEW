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

        // ⚠️ THE ONE THING IN THIS LIST THAT IS NOT CODE, AND THE ONLY FILE THE APP
        // ACTUALLY CARRIES. Everything above is source compiled into the binary; this is
        // somebody else's artwork shipped whole. His decision 2026-09-05: "nerd font is
        // to be default shipped and user can change it."
        //
        // Two notices are required and they are separate works: the TYPEFACE (Meslo LG,
        // Apache 2.0, itself a modification of Apple's Menlo which descends from
        // Bitstream Vera) and the ICON SETS patched into it, which belong to thirteen
        // other projects under six different licences.
        Component(name: "MesloLGM Nerd Font Mono",
                  url: "https://github.com/ryanoasis/nerd-fonts",
                  holder: "Copyright \u{00A9} 2009 Apple Inc. \u{00B7} Copyright \u{00A9} 2006 Tavmjong Bah \u{00B7} Copyright \u{00A9} 2003 Bitstream, Inc.",
                  license: "Apache Licence 2.0 \u{00B7} patched by Nerd Fonts",
                  text: apache(project: "Meslo LG \u{2014} patched as MesloLGM Nerd Font Mono",
                               notice: """
                               Copyright (c) 2009 Apple Inc. All Rights Reserved.
                               Copyright (c) 2006 by Tavmjong Bah. All Rights Reserved.
                               Copyright (c) 2003 by Bitstream, Inc. All Rights Reserved.

                               Meslo LG is a customised version of Apple's Menlo, which is \
                               itself based on Bitstream Vera Sans Mono and the DejaVu \
                               project. This copy has been further modified by the Nerd \
                               Fonts project, which patched additional icon glyphs into it. \
                               The typeface shipped in this app is therefore a modified \
                               work, and this notice records that.
                               """)),

        Component(name: "Nerd Fonts icon sets",
                  url: "https://github.com/ryanoasis/nerd-fonts/blob/master/license-audit.md",
                  holder: "Thirteen projects \u{2014} see the full text",
                  license: "CC BY 4.0 \u{00B7} MIT \u{00B7} OFL 1.1 \u{00B7} Apache 2.0",
                  text: nerdFontIconSets),
    ]

    /// ⚠️ THIRTEEN WORKS IN ONE FILE, AND THE ATTRIBUTION IS PER PROJECT.
    ///
    /// A Nerd Font is a typeface with other people's icons patched into it, and the ones
    /// under CC BY 4.0 and OFL 1.1 require naming and licence terms to travel with the
    /// work. Verified glyph by glyph in the actual bundled file rather than taken from a
    /// list: every set below has glyphs present in it.
    ///
    /// ⚠️ FONT LOGOS IS RECORDED AS HAVING NO STATED LICENCE, and it says so. The Nerd
    /// Fonts project's own licence audit lists it as unlicensed, and 130 of its glyphs
    /// are in this file. Michael was told before the decision to ship. Saying nothing
    /// would have been the dishonest option; crediting the author is the least this can
    /// do, and it is the first thing to revisit if it ever becomes a problem.
    static let nerdFontIconSets = """
    The typeface bundled with this app carries icon glyphs from the projects below, \
    patched in by the Nerd Fonts project. Each remains the property of its authors.

    \u{2014} Font Awesome \u{00B7} Creative Commons Attribution 4.0 International (CC BY 4.0)
    https://fontawesome.com \u{00B7} https://creativecommons.org/licenses/by/4.0/

    \u{2014} Codicons \u{00B7} Creative Commons Attribution 4.0 International (CC BY 4.0)
    Copyright (c) Microsoft Corporation
    https://github.com/microsoft/vscode-codicons \u{00B7} https://creativecommons.org/licenses/by/4.0/

    \u{2014} Weather Icons \u{00B7} SIL Open Font Licence 1.1
    Copyright (c) Erik Flowers
    https://github.com/erikflowers/weather-icons

    \u{2014} Pomicons \u{00B7} SIL Open Font Licence 1.1
    Copyright (c) Gabriel Nazoa and contributors
    https://github.com/gabrielelana/pomicons

    \u{2014} Material Design Icons \u{00B7} Apache Licence 2.0
    Copyright (c) Google and the Material Design Icons contributors
    https://github.com/Templarian/MaterialDesign

    \u{2014} Devicons \u{00B7} MIT Licence
    Copyright (c) Vorillaz
    https://vorillaz.github.io/devicons

    \u{2014} Font Awesome Extension \u{00B7} MIT Licence
    https://github.com/AndreLZGava/font-awesome-extension

    \u{2014} IEC Power Symbols \u{00B7} MIT Licence
    https://unicodepowersymbol.com

    \u{2014} Octicons \u{00B7} MIT Licence
    Copyright (c) GitHub, Inc.
    https://github.com/primer/octicons

    \u{2014} Powerline Extra Symbols \u{00B7} MIT Licence
    Copyright (c) Ryan L McIntyre
    https://github.com/ryanoasis/powerline-extra-symbols

    \u{2014} Seti-UI (modified) \u{00B7} MIT Licence
    https://github.com/jesseweed/seti-ui

    \u{2014} Powerline Symbols \u{00B7} released by its authors for free use
    https://github.com/powerline/powerline

    \u{2014} Font Logos \u{00B7} no licence stated by the project
    Credited here because its glyphs are present and its authors are owed the credit.
    https://github.com/lukas-w/font-logos

    The patching tools themselves are the Nerd Fonts project, MIT Licence.
    Copyright (c) 2014 Ryan L McIntyre
    https://github.com/ryanoasis/nerd-fonts

    \u{2014}\u{2014}\u{2014}

    SIL OPEN FONT LICENCE, Version 1.1 \u{2014} applying to the sets named above as OFL 1.1

    PREAMBLE
    The goals of the Open Font License (OFL) are to stimulate worldwide development of \
    collaborative font projects, to support the font creation efforts of academic and \
    linguistic communities, and to provide a free and open framework in which fonts may \
    be shared and improved in partnership with others.

    The OFL allows the licensed fonts to be used, studied, modified and redistributed \
    freely as long as they are not sold by themselves. The fonts, including any derivative \
    works, can be bundled, embedded, redistributed and/or sold with any software provided \
    that any reserved names are not used by derivative works. The fonts and derivatives, \
    however, cannot be released under any other type of license. The requirement for fonts \
    to remain under this license does not apply to any document created using the fonts or \
    their derivatives.

    PERMISSION & CONDITIONS
    Permission is hereby granted, free of charge, to any person obtaining a copy of the \
    Font Software, to use, study, copy, merge, embed, modify, redistribute, and sell \
    modified and unmodified copies of the Font Software, subject to the following \
    conditions:

    1) Neither the Font Software nor any of its individual components, in Original or \
    Modified Versions, may be sold by itself.

    2) Original or Modified Versions of the Font Software may be bundled, redistributed \
    and/or sold with any software, provided that each copy contains the above copyright \
    notice and this license. These can be included either as stand-alone text files, \
    human-readable headers or in the appropriate machine-readable metadata fields within \
    text or binary files as long as those fields can be easily viewed by the user.

    3) No Modified Version of the Font Software may use the Reserved Font Name(s) unless \
    explicit written permission is granted by the corresponding Copyright Holder. This \
    restriction only applies to the primary font name as presented to the users.

    4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font Software shall \
    not be used to promote, endorse or advertise any Modified Version, except to \
    acknowledge the contribution(s) of the Copyright Holder(s) and the Author(s) or with \
    their explicit written permission.

    5) The Font Software, modified or unmodified, in part or in whole, must be distributed \
    entirely under this license, and must not be distributed under any other license. The \
    requirement for fonts to remain under this license does not apply to any document \
    created using the Font Software.

    TERMINATION
    This license becomes null and void if any of the above conditions are not met.

    DISCLAIMER
    THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
    IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF MERCHANTABILITY, FITNESS FOR A \
    PARTICULAR PURPOSE AND NONINFRINGEMENT OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER \
    RIGHT. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR \
    OTHER LIABILITY, INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR \
    CONSEQUENTIAL DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING \
    FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM OTHER DEALINGS IN \
    THE FONT SOFTWARE.
    """

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
