//
//  ClassParser.swift
//  Mapper
//
//  Created by LZephyr on 2017/9/24.
//  Copyright © 2017年 LZephyr. All rights reserved.
//

import Foundation

// MARK: - ClassNode

/// 保存类型信息的节点
class ClassNode: Node {
    var superCls: ClassNode? = nil // 父类
    var className: String          // 类名
    var protocols: [String] = []   // 协议
    
    init(clsName: String) {
        self.className = clsName
    }
}

extension ClassNode {
    /// 将两个node合并成一个
    func append(_ node: ClassNode) {
        for proto in node.protocols {
            if !protocols.contains(proto) {
                protocols.append(proto)
            }
        }
        
        if superCls == nil && node.superCls != nil {
            superCls = node.superCls
        }
    }
}

extension ClassNode: CustomStringConvertible {
    var description: String {
        var desc = "{class: \(className)"
        
        if let superCls = superCls {
            desc.append(contentsOf: ", superClass: \(superCls.className)")
        }
        
        if protocols.count > 0 {
            desc.append(contentsOf: ", protocols: \(protocols.joined(separator: ", "))")
        }
        
        desc.append(contentsOf: "}")
        return desc
    }
}

extension ClassNode: Hashable {
    static func ==(lhs: ClassNode, rhs: ClassNode) -> Bool {
        return lhs.className == rhs.className
    }
    
    var hashValue: Int {
        return className.hashValue
    }
}

// MARK: - ClassParser

/*
 @interface的文法:
 
 classDecl: '@interface' className (':' className)* protocols
 className: NAME
 protocols: '<' NAME (',' NAME)* '>' | ''
 
 Extension的文法:
 
 extension: '@interface' className '(' ')' protocols
 className: NAME
 protocols: '<' NAME (',' NAME)* '>' | ''
 */

/// 解析class的定义
class ClassParser: Parser {
    
    init(lexer: Lexer) {
        self.input = lexer
        self.currentToken = lexer.nextToken
        self.lastToken = currentToken
    }
    
    /// 解析文件，返回解析结果
    ///
    /// - Returns: 解析结果的节点
    func parse() -> [ClassNode] {
        while currentToken.type != .endOfFile {
            if currentToken.type == .interface {
                do {
                    try classDecl()
                } catch {
                    print(error)
                }
            } else {
                consume()
                continue
            }
        }
        
        merge() // 合并相同的节点
        
        return nodes
    }
    
    // MARK: - Private
    
    fileprivate var input: Lexer
    fileprivate var currentToken: Token
    fileprivate var lastToken: Token       // 上一次解析的节点
    fileprivate var nodes: [ClassNode] = [] // 解析出来的类型节点
    fileprivate var currentNode: ClassNode? = nil // 当前正在解析的节点
    
    /// 匹配当前位置的Token
    fileprivate func match(_ t: TokenType) throws {
        if t != currentToken.type {
            throw ParserError.notMatch("Expected: \(t), found: \(currentToken.type)")
        }
        consume()
    }
    
    /// 向前步进一个Token
    fileprivate func consume() {
        lastToken = currentToken
        currentToken = input.nextToken
    }
    
    // TODO: 暂时不区分category
    /// 合并nodes中相同的结果
    fileprivate func merge() {
        guard nodes.count > 1 else {
            return
        }
        
        var set = Set<ClassNode>()
        for node in nodes {
            if let index = set.index(of: node) {
                set[index].append(node) // 合并相同的节点
            } else {
                set.insert(node)
            }
        }
        
        nodes = Array(set)
    }
}

// MARK: - 文法规则解析

extension ClassParser {
    func classDecl() throws {
        try match(.interface) // @interface关键字
        try match(.name)      // 类名
        
        // 成功匹配到interface定义, 添加到节点中
        let node = ClassNode(clsName: lastToken.text)
        currentNode = node
        nodes.append(node)
        
        if currentToken.type == .colon { // 类型定义，继续匹配父类
            try match(.colon)
            try match(.name) // 父类的名称
            node.superCls = ClassNode(clsName: lastToken.text) // 保存父类的名称
            
            try protocols()  // 实现的协议
        } else if currentToken.type == .lRoundBrack { // 碰到(说明这里为分类定义
            // TODO: 区分category
            try match(.lRoundBrack)
            
            // 括号中没有内容则为匿名分类
            if currentToken.type == .name {
                try match(.name)
            }
            
            try match(.rRoundBrack)
            try protocols()
        }
        
        currentNode = nil
    }
    
    func protocols() throws {
        if currentToken.type == .lAngleBrack {
            try match(.lAngleBrack)
            // 至少有一个协议
            try match(.name)
            currentNode?.protocols.append(lastToken.text)
            
            while currentToken.type == .comma { // 多个协议之间用逗号隔开
                try match(.comma)
                try match(.name)
                currentNode?.protocols.append(lastToken.text)
            }
            try match(.rAngleBrack)
        }
    }
}
