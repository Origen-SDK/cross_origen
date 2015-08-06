require 'spec_helper'

describe "XML Import/Export" do

  before :all do
    RGen.load_target("debug")
    $xml = $dut.rs_ip_xact
  end

  CLEAN_HTML =<<END
<p>Some <em>text</em> from</p>
<p>A couple <strong>of</strong> paragraphs worth of text.</p>

<ul>
  <li>Some bullets</li>
  <li>Some bullets</li>
</ul>

<ol>
  <li>Coffee</li>
  <li>Milk</li>
</ol>

<table>
  <thead>
    <tr>
      <th>First</th>
      <th>Last</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Jill</td>
      <td>Smith</td>
    </tr>
    <tr>
      <td>Eve</td>
      <td>Jackson</td>
    </tr>
  </tbody>
</table>
END

  DIRTY_HTML =<<END
<p>Some <i>text</i> from</p>
<p>A couple <b>of</b> paragraphs worth <xref href="../topics/frequency_modulation.xml"
type="topic" markdown="1"><?ditaot gentext>of text</xref>.</p>

<ul>
  <li>Some bullets</li>
  <li>Some bullets</li>
</ul>

<ol>
  <li>Coffee</li>
  <li>Milk</li>
</ol>

<table>
  <thead>
    <tr>
      <th>First</th>
      <th>Last</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Jill</td>
      <td>Smith</td>
    </tr>
    <tr>
      <td>Eve</td>
      <td>Jackson</td>
    </tr>
  </tbody>
</table>
END

  it "html descriptions can translate back and forward to markdown" do
    html = CLEAN_HTML
  
    md = $xml.to_markdown(html)
    puts md

    # squeeze_lines - don't worry about newline/space differences, these
    # are ignored when rendering HTML anyway
    $xml.to_html(md).squeeze_lines.should == html.squeeze_lines
  end

  it "the descriptions are cleaned up" do
    html = DIRTY_HTML
    md = $xml.to_markdown(html)
    puts md
    $xml.to_html(md).squeeze_lines.should == CLEAN_HTML.squeeze_lines
  end

  it "works with (really) weird description markup" do
    html = File.read("#{RGen.root}/imports/bad_description_1.xml")
    md = $xml.to_markdown(html)
    md.should_not include("could not be imported")
    md.should include('colspan="3"')
    #puts md
  end

  it "basic string descriptions come through ok" do
    md = $xml.to_markdown("Hello there")
    md.should == "Hello there"
  end
end
