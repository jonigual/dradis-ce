# the following let variables must be defined for this to work: record,
# submit_form, column
shared_examples "a page which handles edit conflicts" do
  include RevisionsHelper

  def record_path(record)
    case record
    when Issue
      issue_path(record)
    when Note
      node_note_path(@node, record)
    when Evidence
      node_evidence_path(@node, record)
    end
  end

  def conflict_warning
    "Warning: another user updated this #{record.model_name.name.downcase} "\
    "while you were editing it. Your changes have been saved, but you may "\
    "have overwritten their changes. You may want to review the revision "\
    "history to make sure nothing important has been lost"
  end

  specify "a regular update doesn't say anything about edit conflicts" do
    submit_form
    expect(page).to have_no_content conflict_warning
    expect(page).to have_no_link(//, href: record_revisions_path(record))
  end

  context "when another user has updated the record in the meantime" do
    let(:email_1) { "someone@example.com" }
    before do
      record.update_attributes!(column => "Someone else's changes")
      record.versions.last.update!(whodunnit: email_1)
    end

    it "saves my changes" do
      submit_form
      expect(record.reload.send(column)).to eq new_content
    end

    it "shows the updated record with a warning and a link to the revision history" do
      submit_form
      expect(current_path).to eq record_path(record)
      expect(page).to have_content conflict_warning
      expect(page).to have_link "revision history", href: record_revisions_path(record)
    end

    DATE_FORMAT = "%b %e %Y, %-l:%M%P"

    it "links to the previous versions" do
      submit_form
      all_versions = record.versions.order("created_at ASC")
      my_version   = all_versions[-1]
      conflict     = all_versions[-2]
      old_versions = all_versions - [my_version, conflict]

      expect(page).to have_link(
        "Your update at #{my_version.created_at.strftime(DATE_FORMAT)}",
        href: record_revision_path(record, my_version),
      )

      expect(page).to have_link(
        "Update by #{email_1} at #{conflict.created_at.strftime(DATE_FORMAT)}",
        href: record_revision_path(record, conflict),
      )

      old_versions.each do |version|
        expect(page).to have_no_link(//, record_revision_path(record, version))
      end
    end

    context "when there has been more than one edit" do
      let(:email_2) { "someoneelse@example.com" }
      before do
        record.update_attributes!(column => "More conflicts")
        record.versions.last.update!(whodunnit: email_2)
        submit_form
      end

      it "links to them all" do
        submit_form
        all_versions = record.versions.order("created_at ASC")
        my_version   = all_versions[-1]
        conflicts    = all_versions[-3..-2]
        old_versions = all_versions - [my_version] - conflicts

        expect(page).to have_link(
          "Your update at #{my_version.created_at.strftime(DATE_FORMAT)}",
          href: record_revision_path(record, my_version),
        )

        conflicts.each do |conflict|
          expect(page).to have_link(
            "Update by #{conflict.whodunnit} at #{conflict.created_at.strftime(DATE_FORMAT)}",
            href: record_revision_path(record, conflict),
          )
        end

        old_versions.each do |version|
          expect(page).to have_no_link(//, record_revision_path(record, version))
        end
      end
    end
  end
end
