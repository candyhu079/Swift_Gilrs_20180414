//
//  DataApi.swift
//  SwiftGirls201804
//
//  Created by Candy on 2018/3/19.
//  Copyright © 2018年 SwiftGirls. All rights reserved.
//

import UIKit

private var serverUrl: String = "http://opendata.cwb.gov.tw/govdownload?dataid=E-A0015-001R&authorizationkey=rdec-key-123-45678-011121314"
private var taiwanCountyArray = ["基隆市", "臺北市", "新北市", "桃園市", "新竹市", "新竹縣", "苗栗縣", "臺中市", "南投縣", "彰化縣", "雲林縣", "嘉義市", "嘉義縣", "臺南市", "高雄市", "屏東縣", "宜蘭縣", "花蓮縣", "臺東縣", "澎湖縣", "金門縣", "連江縣"]

class DataApi: NSObject, XMLParserDelegate {
    static var shared: DataApi = DataApi()
    private static var earthquake: Earthquake? = nil  //用這個裝Api 取回的資料

    private var elementName: String = ""  //記錄XMLParser 目前取到的資料名稱
    private var shakingArea: ShakingArea? = nil  //記錄XMLParser 取到的shakingArea(縣市)
    private var stationsArray: [EqStation] = []  //記錄地震測站的陣列
    private var eqStation: EqStation? = nil  //記錄XMLParser 取到的eqStation(測站)
    
    class func getData(completion: @escaping (_ data: Earthquake?, _ error: Error?) -> Void ) {
        let url = URL(string: serverUrl)
        guard url != nil else {
            return
        }
        
        let task = URLSession.shared.dataTask(with: url!, completionHandler: { (data, response, error) in
            guard error == nil && data != nil else {
                return
            }
            let xmlParser = XMLParser(data: data!)
            xmlParser.delegate = self.shared
            
            let success = xmlParser.parse()  //success 是個Boolean 值，紀錄xmlParser 讀取XML 成功與否
            if success {
                // 如果讀取XML 成功，把抓到的earthquake 物件丟給呼叫這個func 的人，且跟他說error 是nil
                completion(earthquake, nil)
            } else {
                // 讀取XML 失敗，產生一個Error 的物件，丟給呼叫這個func 的人，且跟他說data 是nil
                completion(
                    nil,
                    NSError(domain:"Error", code:999, userInfo:["message":"資料錯誤"])
                )
            }
        })
        task.resume()
    }
    
    // MARK: XMLParserDelegate
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        // parse 到element開始的tag
        self.elementName = elementName
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // parse 到element的內容
        if elementName == "earthquake" {
            DataApi.earthquake = Earthquake()
        } else if elementName == "earthquakeInfo" {
            DataApi.earthquake?.earthquakeInfo = EarthquakeInfo()
        } else if elementName == "epicenter" {
            DataApi.earthquake?.earthquakeInfo?.epicenter = Epicenter()
        } else if elementName == "magnitude" {
            DataApi.earthquake?.earthquakeInfo?.magnitude = Magnitude()
        } else if elementName == "intensity" {
            DataApi.earthquake?.intensityArray = []
        } else if elementName == "shakingArea" {
            shakingArea = ShakingArea()
            stationsArray = []
        } else if elementName == "eqStation" {
            eqStation = EqStation()
        }
        // 取到的字串先把空白刪掉，然後判斷字串長度，長度大於0 表示還有字，可以繼續望下執行程式，長度等於0 表示還有沒字了，就不用繼續往下執行了
        guard (string.trimmingCharacters(in: [" ", "\n"])).count > 0 else {
            return
        }
 
        //earthquake
        if elementName == "earthquakeNo" {
            DataApi.earthquake?.earthquakeNo += string
        } else if elementName == "reportContent" {
            DataApi.earthquake?.reportContent += string
        } else if elementName == "web" {
            DataApi.earthquake?.web += string
        } else if elementName == "reportImageURI" {
            DataApi.earthquake?.reportImageURI += string
        } else if elementName == "shakemapImageURI" {
            DataApi.earthquake?.shakemapImageURI += string
        }
        //earthquakeInfo
        else if elementName == "originTime" {
            DataApi.earthquake?.earthquakeInfo?.originTime += string
        }
        //epicenter
        else if elementName == "epicenterLon" {
            DataApi.earthquake?.earthquakeInfo?.epicenter?.epicenterLon = Float(string) ?? 0.0
        } else if elementName == "epicenterLat" {
            DataApi.earthquake?.earthquakeInfo?.epicenter?.epicenterLat = Float(string) ?? 0.0
        } else if elementName == "location" {
            DataApi.earthquake?.earthquakeInfo?.epicenter?.location += string
        }
        //earthquakeInfo
        else if elementName == "depth" {
            DataApi.earthquake?.earthquakeInfo?.depth = Float(string) ?? 0.0
        }
        //magnitude
        else if elementName == "magnitudeType" {
            DataApi.earthquake?.earthquakeInfo?.magnitude?.magnitudeType += string
        } else if elementName == "magnitudeValue" {
            DataApi.earthquake?.earthquakeInfo?.magnitude?.magnitudeValue = Float(string) ?? 0.0
        }
        //shakingArea
        else if elementName == "areaDesc" {
            shakingArea?.areaDesc += string
        } else if elementName == "areaName" {
            shakingArea?.areaName += string
        } else if elementName == "areaIntensity" {
            shakingArea?.areaIntensity = Int(string) ?? 0
        }
        //eqStation
        else if elementName == "stationName" {
            eqStation?.stationName += string
        } else if elementName == "stationLon" {
            eqStation?.stationLon = Float(string) ?? 0.0
        } else if elementName == "stationLat" {
            eqStation?.stationLat = Float(string) ?? 0.0
        } else if elementName == "distance" {
            eqStation?.distance = Float(string) ?? 0.0
        } else if elementName == "stationIntensity" {
            eqStation?.stationIntensity = Int(string) ?? 0
        }
        
        
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        // parse 到element結束的tag
        // 從資料來看，earthquake 裡面的intensity 裡面的shakingArea(縣市)包含了很多eqStation(測站)，所以需要在每一個eqStation 物件做好的時候，把eqStation 加進stationsArray 這個陣列，這個陣列是我在類別最上方宣告用來裝eqStation 的陣列
        if elementName == "eqStation" && eqStation != nil {
            stationsArray.append(eqStation!)
        }
        // 從資料來看，earthquake 裡面的intensity 包含了很多shakingArea(縣市)，所以需要在每一個shakingArea 物件做好的時候，先把做滿eqStation 的stationsArray 放進自己底下(shakingArea 裡面有一個屬性是stationsArray)，再把shakingArea 加進earthquake 裡面的intensityArray 這個陣列
        else if elementName == "shakingArea" && shakingArea != nil {
            shakingArea!.stationsArray = stationsArray
            DataApi.earthquake?.intensityArray?.append(shakingArea!)
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        // 整份文件parse 完畢時進來，把資料裡面shakingArea 不是在敘述縣市的資料過濾掉
        let shakingAreaArray = DataApi.earthquake?.intensityArray?.filter({ (shakingArea) -> Bool in
            taiwanCountyArray.contains(String(shakingArea.areaDesc.prefix(3)))
        })
        
        DataApi.earthquake?.intensityArray = shakingAreaArray
    }
}
