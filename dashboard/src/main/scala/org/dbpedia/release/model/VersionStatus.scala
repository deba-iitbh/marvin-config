package org.dbpedia.release.model

case class VersionStatus(group: String, artifact: String, version: String, expected : Int, actual: Int)
